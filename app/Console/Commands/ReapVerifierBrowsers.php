<?php

namespace App\Console\Commands;

use App\Services\ReplayVerifier;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

/**
 * The browsers of the replay verifier (resources/js/replay-verifier/cdp.mjs) left running: their script was killed
 * before it could close them, and the game in them goes on (100% of a CPU). Found by the temporary profile of the
 * browser (<tmp>/kado-verifier-*), in the command line of all their processes (their environment cannot be read by
 * another user without CAP_SYS_PTRACE: the cron runs as root, the worker as dev). Linux only (/proc).
 */
class ReapVerifierBrowsers extends Command
{
    protected $signature = 'kado:replay-verifier:reap {--older-than= : seconds (default: the timeout of the verifier and a margin)}';

    protected $description = 'Kill the browsers of the replay verifier left running, remove their profiles';

    // the clock ticks of /proc/<pid>/stat (USER_HZ, always 100 on Linux x86 and arm)
    private const TICKS = 100;

    private const PROFILE = 'kado-verifier-';

    public function handle()
    {
        if (!is_dir('/proc/self')) {
            $this->warn('no /proc: nothing done');

            return self::SUCCESS;
        }
        $olderThan = $this->option('older-than') !== null
            ? (int) $this->option('older-than')
            : (int) config('kado.replay_verifier.timeout') + ReplayVerifier::KILL_AFTER_SECONDS + 60;
        $bootTime = $this->bootTime();

        $killed = 0;
        foreach (glob('/proc/[0-9]*', GLOB_ONLYDIR) ?: [] as $dir) {
            $pid = (int) basename($dir);
            if ($pid === getmypid() || !$this->isVerifierBrowser($dir)) {
                continue;
            }
            $age = $this->age($dir, $bootTime);
            if ($age === null || $age < $olderThan) {
                continue;
            }
            if ($this->kill($pid)) {
                $killed++;
            }
        }

        // the profiles of the browsers killed (cdp.mjs removes them when it closes its browser)
        $removed = 0;
        foreach (glob(rtrim(sys_get_temp_dir(), '/').'/'.self::PROFILE.'*', GLOB_ONLYDIR) ?: [] as $profile) {
            if (time() - (int) @filemtime($profile) >= $olderThan && File::deleteDirectory($profile)) {
                $removed++;
            }
        }

        if ($killed > 0) {
            info("kado:replay-verifier:reap: {$killed} processes of browsers of the replay verifier killed");
        }
        $this->info("{$killed} processes killed, {$removed} profiles removed");

        return self::SUCCESS;
    }

    // a process of a browser of the verifier: --user-data-dir (crashpad: --database) in its profile
    private function isVerifierBrowser(string $dir): bool
    {
        // (the arguments of the command line end with \0)
        return (bool) preg_match(
            '#(?:^|\0)--(?:user-data-dir|database)=[^\0]*/'.self::PROFILE.'#',
            (string) @file_get_contents("{$dir}/cmdline"),
        );
    }

    // seconds since the process started (field 22 of /proc/<pid>/stat, in ticks since the boot)
    private function age(string $dir, ?int $bootTime): ?int
    {
        $stat = @file_get_contents("{$dir}/stat");
        if ($bootTime === null || !$stat) {
            return null;
        }
        // the name of the command (field 2) is in parentheses and may contain spaces: the fields after it from 3
        $fields = explode(' ', substr($stat, strrpos($stat, ')') + 2));
        if (!isset($fields[19])) {
            return null;
        }

        return time() - ($bootTime + intdiv((int) $fields[19], self::TICKS));
    }

    private function bootTime(): ?int
    {
        $stat = @file_get_contents('/proc/stat');

        return $stat && preg_match('/^btime (\d+)$/m', $stat, $m) ? (int) $m[1] : null;
    }

    private function kill(int $pid): bool
    {
        if (function_exists('posix_kill')) {
            return posix_kill($pid, 9);
        }
        exec('kill -9 '.$pid, result_code: $code);

        return $code === 0;
    }
}
