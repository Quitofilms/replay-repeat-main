import { module, test } from "qunit";

import { youTubeIdOf } from "#utils/youtube.ts";

module("Unit | youTubeIdOf", function () {
  const valid: [string, string][] = [
    ["dQw4w9WgXcQ", "a bare id"],
    ["https://www.youtube.com/watch?v=dQw4w9WgXcQ", "a watch link"],
    ["https://www.youtube.com/watch?list=PL1&v=dQw4w9WgXcQ&t=42s", "a watch link with more params"],
    ["youtube.com/watch?v=dQw4w9WgXcQ", "a link without the protocol"],
    ["https://m.youtube.com/watch?v=dQw4w9WgXcQ", "a mobile link"],
    ["https://music.youtube.com/watch?v=dQw4w9WgXcQ", "a music link"],
    ["https://youtu.be/dQw4w9WgXcQ?si=abc", "a short link"],
    ["https://www.youtube.com/shorts/dQw4w9WgXcQ", "a shorts link"],
    ["https://www.youtube.com/embed/dQw4w9WgXcQ", "an embed link"],
    ["https://www.youtube.com/live/dQw4w9WgXcQ", "a live link"],
    ["  https://youtu.be/dQw4w9WgXcQ  ", "a link with spaces around it"],
  ];

  for (const [input, name] of valid) {
    test(`finds the id in ${name}`, function (assert) {
      assert.strictEqual(youTubeIdOf(input), "dQw4w9WgXcQ");
    });
  }

  const invalid: [string, string][] = [
    ["", "an empty string"],
    ["https://example.com/watch?v=dQw4w9WgXcQ", "another site"],
    ["https://www.youtube.com/watch", "a watch link without an id"],
    ["https://www.youtube.com/@someone", "a channel link"],
    ["not a link", "some words"],
  ];

  for (const [input, name] of invalid) {
    test(`finds no id in ${name}`, function (assert) {
      assert.strictEqual(youTubeIdOf(input), undefined);
    });
  }
});
