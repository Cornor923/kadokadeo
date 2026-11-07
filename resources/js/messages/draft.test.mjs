// node --test resources/js/messages/draft.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { messageDraft } from './draft.js'

const link = 'https://example.org/runs/1'

test('joins the text and the link', () => {
  assert.equal(messageDraft({ text: 'Regarde', url: link }).body, `Regarde\n${link}`)
})

test('keeps the link once when the text holds it already', () => {
  assert.equal(messageDraft({ text: `Regarde ${link}`, url: link }).body, `Regarde ${link}`)
})

test('takes the link alone', () => {
  assert.equal(messageDraft({ url: link }).body, link)
})

test('the subject of an answer wins over a shared title', () => {
  assert.equal(messageDraft({ subject: 'Re: salut', title: 'Partagé' }).subject, 'Re: salut')
  assert.equal(messageDraft({ title: 'Partagé' }).subject, 'Partagé')
})

test('gives nothing for an empty URL', () => {
  assert.deepEqual(messageDraft({}), { to: null, subject: null, body: null })
})

test('cuts at the limits of the form', () => {
  const { subject, body } = messageDraft({ title: 'a'.repeat(200), text: 'b'.repeat(6000) })
  assert.equal(subject.length, 100)
  assert.equal(body.length, 5000)
})
