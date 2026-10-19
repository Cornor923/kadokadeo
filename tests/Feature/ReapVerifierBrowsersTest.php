<?php

namespace Tests\Feature;

use Symfony\Component\Process\Process;
use Tests\TestCase;

class ReapVerifierBrowsersTest extends TestCase
{
    private array $processes = [];

    protected function tearDown(): void
    {
        foreach ($this->processes as $process) {
            $process->stop(0);
        }
        parent::tearDown();
    }

    // a process with the arguments of a browser of the verifier (or not)
    private function process(string $argument): Process
    {
        if (!is_dir('/proc/self')) {
            $this->markTestSkipped('no /proc');
        }
        $process = new Process([PHP_BINARY, '-r', 'sleep(30);', '--', $argument]);
        $process->start();
        $this->processes[] = $process;
        // its command line is the one of PHP until it has started
        for ($i = 0; $i < 100 && !str_contains((string) @file_get_contents("/proc/{$process->getPid()}/cmdline"), $argument); $i++) {
            usleep(10_000);
        }

        return $process;
    }

    public function test_the_old_browsers_of_the_verifier_are_killed(): void
    {
        $browser = $this->process('--user-data-dir=/tmp/kado-verifier-Ab12Cd');
        $crashpad = $this->process('--database=/tmp/kado-verifier-Ab12Cd/.config/chromium/Crash Reports');
        $other = $this->process('/tmp/kado-verifier-Ab12Cd');

        $this->artisan('kado:replay-verifier:reap', ['--older-than' => 0])->assertSuccessful();
        usleep(100_000);

        $this->assertFalse($browser->isRunning());
        $this->assertFalse($crashpad->isRunning());
        $this->assertTrue($other->isRunning());
    }

    public function test_a_browser_younger_than_the_timeout_is_left_alone(): void
    {
        $browser = $this->process('--user-data-dir=/tmp/kado-verifier-Ab12Cd');

        $this->artisan('kado:replay-verifier:reap')->assertSuccessful();

        $this->assertTrue($browser->isRunning());
    }
}
