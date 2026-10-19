<?php

namespace Tests\Feature;

use App\Models\Clan;
use App\Models\ClanForumMessage;
use App\Models\ClanForumTopic;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\EnablesClans;
use Tests\TestCase;

class ClanForumTest extends TestCase
{
    use EnablesClans, RefreshDatabase;

    private User $leader;

    private User $rightHand;

    private User $member;

    private Clan $clan;

    protected function setUp(): void
    {
        parent::setUp();
        [$this->leader, $this->rightHand, $this->member] = User::factory()->count(3)->create();
        $this->clan = Clan::factory()->withLeader($this->leader)->create();
        $this->clan->members()->create(['user_id' => $this->rightHand->id, 'role' => 'right_hand']);
        $this->clan->members()->create(['user_id' => $this->member->id]);
    }

    private function topic(User $author, string $title = 'Les records', string $content = 'Premier message'): ClanForumTopic
    {
        Sanctum::actingAs($author);
        $id = $this->postJson("/api/clans/{$this->clan->id}/forum/topics", ['title' => $title, 'content' => $content])
            ->assertCreated()
            ->json('data.id');

        return ClanForumTopic::query()->findOrFail($id);
    }

    private function reply(User $author, ClanForumTopic $topic, string $content = 'Une réponse'): int
    {
        Sanctum::actingAs($author);

        return $this->postJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}/messages", ['content' => $content])
            ->assertCreated()
            ->json('data.id');
    }

    // a topic is created with its first message, the answers update the "Msg" and "Réponses" columns
    public function test_a_member_creates_a_topic_and_answers(): void
    {
        $topic = $this->topic($this->member, 'Les records (68, 4)', "**Records** du clan\n:kk-smile:");
        $this->assertSame(0, $topic->replies_count);
        $this->assertSame($this->member->id, $topic->last_message_user_id);

        $this->reply($this->leader, $topic);
        $this->reply($this->rightHand, $topic);
        $topic->refresh();
        $this->assertSame(2, $topic->replies_count);
        $this->assertSame($this->rightHand->id, $topic->last_message_user_id);

        Sanctum::actingAs($this->member);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics")
            ->assertOk()
            ->assertJsonPath('data.0.title', 'Les records (68, 4)')
            ->assertJsonPath('data.0.replies_count', 2)
            ->assertJsonPath('data.0.author.display_name', $this->member->display_name)
            ->assertJsonPath('data.0.last_message_user.display_name', $this->rightHand->display_name)
            ->assertJsonPath('viewer.can_moderate', false);

        // the Marktwin is kept as written: the client renders it
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}")
            ->assertOk()
            ->assertJsonPath('topic.title', 'Les records (68, 4)')
            ->assertJsonPath('data.0.content', "**Records** du clan\n:kk-smile:")
            ->assertJsonPath('data.0.can_edit', true)
            ->assertJsonPath('data.1.author_role', 'leader')
            ->assertJsonPath('data.1.author_role_label', 'Chef de clan')
            ->assertJsonPath('data.1.can_edit', false)
            ->assertJsonPath('data.2.author_role', 'right_hand')
            ->assertJsonCount(3, 'data');
    }

    public function test_the_title_and_the_content_are_required(): void
    {
        Sanctum::actingAs($this->member);
        $this->postJson("/api/clans/{$this->clan->id}/forum/topics", ['title' => 'a', 'content' => ''])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['title', 'content']);
    }

    // the forum is private: a player outside the clan can neither read it nor write in it, and a topic of another clan
    // is not found through this clan
    public function test_only_the_members_see_the_forum(): void
    {
        $topic = $this->topic($this->member);
        $outsider = User::factory()->create();
        $other = Clan::factory()->withLeader($outsider)->create();

        Sanctum::actingAs($outsider);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics")->assertStatus(422)
            ->assertJsonPath('message', 'Vous ne faites pas partie de ce clan.');
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}")->assertStatus(422);
        $this->postJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}/messages", ['content' => 'coucou'])->assertStatus(422);
        $this->getJson("/api/clans/{$other->id}/forum/topics/{$topic->id}")->assertNotFound();
    }

    public function test_a_guest_is_refused(): void
    {
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics")->assertUnauthorized();
    }

    // the leader and the right hands pin and lock the topics, a member can't
    public function test_the_moderators_pin_and_lock_the_topics(): void
    {
        $old = $this->topic($this->member, 'Ancien sujet');
        $this->travel(1)->minutes();
        $this->topic($this->member, 'Sujet récent');

        Sanctum::actingAs($this->member);
        $this->patchJson("/api/clans/{$this->clan->id}/forum/topics/{$old->id}", ['is_pinned' => true])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Seuls le chef de clan et ses bras droits peuvent faire ça.');
        // the author changes his title
        $this->patchJson("/api/clans/{$this->clan->id}/forum/topics/{$old->id}", ['title' => 'Ancien sujet (édité)'])->assertNoContent();

        Sanctum::actingAs($this->rightHand);
        $this->patchJson("/api/clans/{$this->clan->id}/forum/topics/{$old->id}", ['is_pinned' => true, 'is_locked' => true])->assertNoContent();
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics")
            ->assertJsonPath('data.0.title', 'Ancien sujet (édité)')
            ->assertJsonPath('data.0.is_pinned', true)
            ->assertJsonPath('data.0.is_locked', true)
            ->assertJsonPath('data.1.title', 'Sujet récent')
            ->assertJsonPath('viewer.can_moderate', true);

        // locked: only the moderators answer
        Sanctum::actingAs($this->member);
        $this->postJson("/api/clans/{$this->clan->id}/forum/topics/{$old->id}/messages", ['content' => 'Encore moi'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Ce sujet est verrouillé.');
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics/{$old->id}")
            ->assertJsonPath('viewer.can_reply', false)
            ->assertJsonPath('viewer.can_rename', true)
            ->assertJsonPath('data.0.can_edit', false);
        $this->reply($this->leader, $old, 'Le chef répond quand même');
    }

    // a deleted message is kept: its content is hidden from the members, the moderators can restore it
    public function test_the_moderators_delete_and_restore_the_messages(): void
    {
        $topic = $this->topic($this->member);
        $messageId = $this->reply($this->member, $topic, 'Message à modérer');

        Sanctum::actingAs($this->member);
        $this->deleteJson("/api/clans/{$this->clan->id}/forum/messages/{$messageId}")->assertStatus(422);

        Sanctum::actingAs($this->leader);
        $this->deleteJson("/api/clans/{$this->clan->id}/forum/messages/{$messageId}")->assertNoContent();
        $this->assertSoftDeleted('clan_forum_messages', ['id' => $messageId, 'deleted_by' => $this->leader->id]);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}")
            ->assertJsonPath('data.1.is_deleted', true)
            ->assertJsonPath('data.1.content', 'Message à modérer');

        Sanctum::actingAs($this->member);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}")
            ->assertJsonPath('data.1.is_deleted', true)
            ->assertJsonPath('data.1.content', null)
            ->assertJsonPath('data.1.can_edit', false);
        $this->patchJson("/api/clans/{$this->clan->id}/forum/messages/{$messageId}", ['content' => 'Je triche'])->assertStatus(422);

        Sanctum::actingAs($this->rightHand);
        $this->postJson("/api/clans/{$this->clan->id}/forum/messages/{$messageId}/restore")->assertNoContent();
        $this->assertNotSoftDeleted('clan_forum_messages', ['id' => $messageId, 'deleted_by' => null]);
    }

    // the author edits his message, a moderator any message, another member none
    public function test_the_messages_are_edited_by_their_author_or_a_moderator(): void
    {
        $topic = $this->topic($this->member, 'Sujet', 'Version 1');
        $messageId = ClanForumMessage::query()->where('topic_id', $topic->id)->value('id');

        Sanctum::actingAs($this->member);
        $this->patchJson("/api/clans/{$this->clan->id}/forum/messages/{$messageId}", ['content' => 'Version 2'])->assertNoContent();
        $this->assertDatabaseHas('clan_forum_messages', ['id' => $messageId, 'content' => 'Version 2', 'edited_by' => $this->member->id]);

        $other = User::factory()->create();
        $this->clan->members()->create(['user_id' => $other->id]);
        Sanctum::actingAs($other);
        $this->patchJson("/api/clans/{$this->clan->id}/forum/messages/{$messageId}", ['content' => 'Pas à moi'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Vous ne pouvez pas modifier ce message.');

        Sanctum::actingAs($this->rightHand);
        $this->patchJson("/api/clans/{$this->clan->id}/forum/messages/{$messageId}", ['content' => 'Modéré'])->assertNoContent();
        $this->assertDatabaseHas('clan_forum_messages', ['id' => $messageId, 'content' => 'Modéré', 'edited_by' => $this->rightHand->id]);
    }

    public function test_the_moderators_delete_the_topics(): void
    {
        $topic = $this->topic($this->member);
        $this->reply($this->member, $topic);

        Sanctum::actingAs($this->member);
        $this->deleteJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}")->assertStatus(422);

        Sanctum::actingAs($this->leader);
        $this->deleteJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}")->assertNoContent();
        $this->assertDatabaseMissing('clan_forum_topics', ['id' => $topic->id]);
        $this->assertDatabaseCount('clan_forum_messages', 0);
    }

    // a topic is unread until its last message is shown to the player
    public function test_the_topics_are_read_and_unread(): void
    {
        $topic = $this->topic($this->member);

        Sanctum::actingAs($this->member);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics")->assertJsonPath('data.0.is_unread', false);
        Sanctum::actingAs($this->leader);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics")->assertJsonPath('data.0.is_unread', true);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}")->assertOk();
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics")->assertJsonPath('data.0.is_unread', false);

        $this->reply($this->rightHand, $topic);
        Sanctum::actingAs($this->leader);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics")->assertJsonPath('data.0.is_unread', true);
    }

    // 10 messages a page: the first message and its answers
    public function test_the_messages_are_paginated(): void
    {
        $topic = $this->topic($this->member);
        foreach (range(1, 10) as $i) {
            $this->reply($this->member, $topic, "Réponse {$i}");
        }

        Sanctum::actingAs($this->leader);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics")->assertJsonPath('data.0.pages', 2);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}")
            ->assertJsonCount(10, 'data')
            ->assertJsonPath('meta.last_page', 2);
        $this->getJson("/api/clans/{$this->clan->id}/forum/topics/{$topic->id}?page=last")
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.content', 'Réponse 10')
            ->assertJsonPath('meta.current_page', 2);
        // read up to the last page shown
        $this->assertDatabaseHas('clan_forum_reads', ['user_id' => $this->leader->id, 'last_read_message_id' => $topic->refresh()->last_message_id]);
    }

    // the search looks in the titles and in the messages still shown
    public function test_the_search_looks_in_the_titles_and_the_messages(): void
    {
        $this->topic($this->member, 'Tournoi période 68', 'Inscriptions ouvertes');
        $hidden = $this->topic($this->member, 'Vacances', 'Je pars au Japon');
        $this->topic($this->member, 'Alchimie', 'Mon record au Japon');
        $messageId = ClanForumMessage::query()->where('topic_id', $hidden->id)->value('id');
        Sanctum::actingAs($this->leader);
        $this->deleteJson("/api/clans/{$this->clan->id}/forum/messages/{$messageId}")->assertNoContent();

        $titles = fn (string $q) => collect($this->getJson("/api/clans/{$this->clan->id}/forum/topics?q=".urlencode($q))->assertOk()->json('data'))->pluck('title')->all();
        $this->assertSame(['Tournoi période 68'], $titles('tournoi'));
        $this->assertSame(['Alchimie'], $titles('japon'));
        // the wildcards of LIKE are not wildcards
        $this->assertSame([], $titles('pér%68x'));
    }
}
