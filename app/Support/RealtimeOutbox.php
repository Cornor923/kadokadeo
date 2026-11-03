<?php

namespace App\Support;

use App\Events\RealtimeEvent;
use Illuminate\Broadcasting\BroadcastException;
use Illuminate\Container\Attributes\Scoped;
use Illuminate\Support\Facades\Cache;
use Throwable;

use function Illuminate\Support\defer;

// the events of the realtime of a request (a command, a job), sent once its response is sent (defer: the player does not
// wait for Reverb), each once (RealtimeEvent::dedupeKey). One by request or job (scoped)
#[Scoped]
class RealtimeOutbox
{
    // Reverb did not answer: nothing more is sent for that long, rather than waiting for its timeouts at each event of
    // each request (the front polls meanwhile, and reloads what it shows when its socket connects again)
    public const DOWN_SECONDS = 30;

    private const DOWN_KEY = 'realtime:down';

    /** @var array<int|string, RealtimeEvent> */
    private array $events = [];

    public function push(RealtimeEvent $event): void
    {
        $first = $this->events === [];
        $key = $event->dedupeKey();
        if ($key === null) {
            $this->events[] = $event;
        } else {
            // (at the place of the first one)
            $key = $event::class.':'.$key;
            $this->events[$key] = isset($this->events[$key]) ? $event->mergedWith($this->events[$key]) : $event;
        }

        // once the event is kept: without defer (the tests), the callback runs at once. Always: also after an error
        // response, what was committed before it is done
        if ($first) {
            defer(fn () => $this->flush(), 'realtime', always: true);
        }
    }

    public function flush(): void
    {
        $events = $this->events;
        $this->events = [];
        if ($events === [] || Cache::has(self::DOWN_KEY)) {
            return;
        }

        foreach ($events as $event) {
            try {
                event($event);
            } catch (BroadcastException $e) {
                Cache::put(self::DOWN_KEY, true, self::DOWN_SECONDS);
                report($e);

                return;
            } catch (Throwable $e) {
                report($e);
            }
        }
    }
}
