<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Symfony\Component\Console\Output\ConsoleOutputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Process\Process;

class RunWorker extends Command
{
    protected $signature = 'kado:worker
        {--queue-args= : arguments of queue:work, e.g. "--tries=3 --max-time=3600"}
        {--reverb-args= : arguments of reverb:start}';

    protected $description = 'Run the queue worker and the Reverb server in one process (one systemd service)';

    private const POLL_MICROSECONDS = 500_000;

    // delay before starting again a child that stopped, doubled while it stops quickly
    private const MIN_BACKOFF_SECONDS = 1;

    private const MAX_BACKOFF_SECONDS = 30;

    // a child that ran that long is fine: the delay goes back to MIN_BACKOFF_SECONDS
    private const STABLE_AFTER_SECONDS = 60;

    // a child that keeps failing that many times in a row: this command fails (systemd starts it again, Restart=always)
    private const MAX_QUICK_FAILURES = 5;

    // time given to a child to stop on SIGTERM before SIGKILL (under TimeoutStopSec of the service)
    private const STOP_GRACE_SECONDS = 60;

    /** @var array<string, array{command: list<string>, process: ?Process, startedAt: float, restartAt: float, backoff: int, failures: int, partial: array<string, string>}> */
    private array $children = [];

    public function handle()
    {
        $this->children['queue'] = $this->child('queue:work', $this->option('queue-args'));
        if ($this->getApplication()->has('reverb:start')) {
            $this->children['reverb'] = $this->child('reverb:start', $this->option('reverb-args'));
        } else {
            $this->warn('reverb:start is not available (laravel/reverb not installed): queue worker only');
        }

        // stopped by systemd (KillMode=control-group: SIGTERM to this process and its children)
        while (true) {
            foreach ($this->children as $name => &$child) {
                $process = $child['process'];
                if ($process !== null && $process->isRunning()) {
                    continue;
                }
                if ($process !== null) {
                    $this->stopped($name, $child);
                    if ($child['failures'] >= self::MAX_QUICK_FAILURES) {
                        $this->error("[{$name}] failed {$child['failures']} times in a row: stopping");
                        unset($child);
                        $this->stopAll();

                        return self::FAILURE;
                    }
                }
                if (microtime(true) >= $child['restartAt']) {
                    $this->start($name, $child);
                }
            }
            unset($child);
            usleep(self::POLL_MICROSECONDS);
        }
    }

    /** @return array{command: list<string>, process: null, startedAt: float, restartAt: float, backoff: int, failures: int, partial: array<string, string>} */
    private function child(string $command, ?string $args): array
    {
        return [
            'command' => [PHP_BINARY, base_path('artisan'), $command, ...preg_split('/\s+/', trim((string) $args), -1, PREG_SPLIT_NO_EMPTY)],
            'process' => null,
            'startedAt' => 0.0,
            'restartAt' => 0.0,
            'backoff' => self::MIN_BACKOFF_SECONDS,
            'failures' => 0,
            'partial' => [Process::OUT => '', Process::ERR => ''],
        ];
    }

    private function start(string $name, array &$child): void
    {
        $process = new Process($child['command'], base_path(), null, null, null);
        $process->start(function (string $type, string $buffer) use ($name, &$child) {
            $this->relay($name, $type, $child['partial'][$type].$buffer, $child['partial'][$type]);
        });
        $child['process'] = $process;
        $child['startedAt'] = microtime(true);
        $this->line("[{$name}] started (pid {$process->getPid()})");
    }

    // a child that stopped by itself: when to start it again
    private function stopped(string $name, array &$child): void
    {
        $process = $child['process'];
        $child['process'] = null;
        foreach ($child['partial'] as $type => $rest) {
            $this->relay($name, $type, $rest === '' ? '' : $rest."\n", $child['partial'][$type]);
        }

        if (microtime(true) - $child['startedAt'] >= self::STABLE_AFTER_SECONDS) {
            $child['backoff'] = self::MIN_BACKOFF_SECONDS;
            $child['failures'] = 0;
        }
        if ($process->getExitCode() !== 0) {
            $child['failures']++;
        }
        $child['restartAt'] = microtime(true) + $child['backoff'];
        $this->line("[{$name}] stopped (exit code {$process->getExitCode()})"
            .($child['failures'] < self::MAX_QUICK_FAILURES ? ", started again in {$child['backoff']} s" : ''));
        $child['backoff'] = min($child['backoff'] * 2, self::MAX_BACKOFF_SECONDS);
    }

    private function stopAll(): void
    {
        $this->line('stopping');
        foreach ($this->children as $name => $child) {
            if ($child['process']?->isRunning()) {
                $code = $child['process']->stop(self::STOP_GRACE_SECONDS);
                $this->line("[{$name}] stopped (exit code {$code})");
            }
        }
    }

    // the complete lines of the output of a child, with its name; the last line, not ended yet, is kept in $partial
    private function relay(string $name, string $type, string $text, string &$partial): void
    {
        $lines = explode("\n", $text);
        $partial = array_pop($lines);
        if ($lines === []) {
            return;
        }
        $output = $type === Process::ERR && $this->output->getOutput() instanceof ConsoleOutputInterface
            ? $this->output->getOutput()->getErrorOutput()
            : $this->output->getOutput();
        foreach (array_filter($lines, fn ($line) => trim($line) !== '') as $line) {
            $output->writeln("[{$name}] {$line}", OutputInterface::OUTPUT_RAW);
        }
    }
}
