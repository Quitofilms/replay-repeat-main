import { module, test } from "qunit";

import { formatTime } from "#utils/time.ts";

module("Unit | formatTime", function () {
  test("minutes, seconds, and tenths", function (assert) {
    assert.strictEqual(formatTime(0), "0:00.0");
    assert.strictEqual(formatTime(5.25), "0:05.3");
    assert.strictEqual(formatTime(59.96), "1:00.0");
    assert.strictEqual(formatTime(65), "1:05.0");
  });

  test("hours, when the video is that long", function (assert) {
    assert.strictEqual(formatTime(3725.5), "1:02:05.5");
  });

  test("no negative times", function (assert) {
    assert.strictEqual(formatTime(-1), "0:00.0");
  });
});
