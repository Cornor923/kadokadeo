<?php

namespace Tests\Unit;

use App\Support\ReplayHeader;
use PHPUnit\Framework\TestCase;

class ReplayHeaderTest extends TestCase
{
    // like ReplayManager.encodeReplayString: base64 of the zlib deflated binary replay
    public static function replay(int $flags, int $version = 3): string
    {
        return base64_encode(gzcompress('KADO'.chr($version).chr($flags)."\x00\x00", 9));
    }

    public function test_it_reads_the_version_and_the_flags(): void
    {
        $header = ReplayHeader::parse(self::replay(ReplayHeader::FLAG_RNG_STIR | 1));

        $this->assertSame(3, $header->version);
        $this->assertTrue($header->hasRngStir());
        $this->assertFalse(ReplayHeader::parse(self::replay(1))->hasRngStir());
    }

    // a game of Binary recorded by the game (2026-10): version 4, stir, events and phases, 421 frames
    public const BINARY_V4 = 'eNrzdnTxZzmkzMDIIMHOyBBhCaQZGRmEmRkZguWANJDNDGQ7A9lCQHaQJ5BmAtIqEL4kCyNDpCKQBqljgqjjBqr3BtFAvgBQPIAVQksCxSNVIGrBZrBCaA4g9gCyOWBqlFmTa02NaqWTpP1qdWv1cmql3e3Ya9Mcas28amN5a50rak3ZfVz9ljIDALgRFZE=';

    public function test_it_reads_a_version_4_replay_with_the_phases_of_the_inputs(): void
    {
        $header = ReplayHeader::parse(self::BINARY_V4);

        $this->assertSame(4, $header->version);
        $this->assertTrue($header->hasRngStir());
        $this->assertTrue($header->hasInputPhases());
        $this->assertSame(421, $header->frames);
        // the flag means nothing before version 4
        $this->assertFalse(ReplayHeader::parse(self::replay(ReplayHeader::FLAG_INPUT_PHASES))->hasInputPhases());
    }

    public function test_it_reads_the_number_of_frames_of_the_trailer(): void
    {
        $replay = fn (string $trailer) => base64_encode(gzcompress("KADO\x04\x41\x00\x00".$trailer, 9));

        $this->assertSame(0, ReplayHeader::parse($replay("LEN\x00"))->frames);
        $this->assertSame(127, ReplayHeader::parse($replay("LEN\x7F"))->frames);
        $this->assertSame(300, ReplayHeader::parse($replay("LEN\xAC\x02"))->frames);
        $this->assertSame(2097152, ReplayHeader::parse($replay("LEN\x80\x80\x80\x01"))->frames);
        // no trailer (older replays), or not a varint
        $this->assertNull(ReplayHeader::parse(self::replay(1))->frames);
        $this->assertNull(ReplayHeader::parse($replay("LEN\x80"))->frames);
    }

    public function test_it_reads_the_first_replays_which_were_not_deflated(): void
    {
        $this->assertSame(1, ReplayHeader::parse(base64_encode("KADO\x01\x01\x00"))->version);
    }

    public function test_it_ignores_what_is_not_a_replay(): void
    {
        $this->assertNull(ReplayHeader::parse(null));
        $this->assertNull(ReplayHeader::parse('not base64 !'));
        $this->assertNull(ReplayHeader::parse(base64_encode(gzcompress('NOPE'))));
        $this->assertNull(ReplayHeader::parse('936 bytes'));
    }

    // a small replay made to inflate to more than the limit (a zip bomb) is not inflated
    public function test_it_does_not_inflate_past_the_limit(): void
    {
        $deflate = deflate_init(ZLIB_ENCODING_DEFLATE, ['level' => 9]);
        $bomb = deflate_add($deflate, "KADO\x04\x41", ZLIB_NO_FLUSH);
        $zeros = str_repeat("\x00", 1024 * 1024);
        // (zlib_decode may go a bit past the limit before it stops)
        for ($i = 0; $i < 4 * ReplayHeader::MAX_INFLATED_BYTES / strlen($zeros); $i++) {
            $bomb .= deflate_add($deflate, $zeros, ZLIB_NO_FLUSH);
        }
        $bomb = base64_encode($bomb.deflate_add($deflate, '', ZLIB_FINISH));

        $this->assertLessThan(200_000, strlen($bomb));
        $this->assertNull(ReplayHeader::parse($bomb));
        $this->assertSame(4, ReplayHeader::parse(base64_encode(gzcompress("KADO\x04\x41".str_repeat("\x00", 1000), 9)))->version);
    }
}
