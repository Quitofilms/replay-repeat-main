import {
  click,
  currentURL,
  fillIn,
  find,
  findAll,
  settled,
  triggerEvent,
  triggerKeyEvent,
  visit,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupApplicationTest } from "ember-qunit";

import videoUrl from "../fixtures/ten-seconds.webm?url";

async function clickTab(name: string) {
  const tab = findAll('[role="tab"]').find((element) => element.textContent?.trim() === name);

  if (!tab) throw new Error(`No tab named ${name}`);

  await click(tab);
}

function video() {
  const element = find("video");

  if (!(element instanceof HTMLVideoElement)) throw new Error("No video is rendered");

  return element;
}

/**
 * Seeks like the native video controls do,
 * then waits for the time display to show it.
 */
async function seekTo(seconds: number, shown: string) {
  video().currentTime = seconds;
  await waitUntil(() => find("[data-test-now]")?.textContent === shown);
}

/**
 * The query params in the URL, as an object.
 */
function queryParams() {
  return Object.fromEntries(new URL(currentURL(), "https://replay.invalid").searchParams);
}

async function theTestVideo() {
  const blob = await (await fetch(videoUrl)).blob();

  return new File([blob], "ten-seconds.webm", { type: "video/webm" });
}

/**
 * A real DragEvent with a file, as the browser makes for a drag from the desktop.
 */
async function dragOverPage(type: string, file: File) {
  const dataTransfer = new DataTransfer();

  dataTransfer.items.add(file);
  document.body.dispatchEvent(
    new DragEvent(type, { bubbles: true, cancelable: true, dataTransfer }),
  );
  await settled();
}

async function loadTheTestVideo() {
  await visit("/");
  await clickTab("File on disk");

  await triggerEvent(".nvp__file-drop input[type=file]", "change", {
    files: [await theTestVideo()],
  });
  await waitFor("[data-test-duration]");
}

module("Application | replay", function (hooks) {
  setupApplicationTest(hooks);

  test("the header links to the source on GitHub", async function (assert) {
    await visit("/");

    assert.dom("[data-test-github]").hasText("GitHub");
    assert
      .dom("[data-test-github]")
      .hasAttribute("href", "https://github.com/NullVoxPopuli/replay-repeat");
    assert.dom("[data-test-github]").hasAttribute("target", "_blank");
  });

  test("with no video, a welcome explains the privacy", async function (assert) {
    await visit("/");

    assert.dom("[data-test-welcome] h2").hasText("Pick a video to start");
    assert.dom("[data-test-welcome]").includesText("no server and no permissions");
    assert.dom("[data-test-welcome] svg").hasAria("hidden", "true");

    await loadTheTestVideo();

    assert.dom("[data-test-welcome]").doesNotExist();
  });

  test("a video dropped anywhere on the page loads", async function (assert) {
    await visit("/");

    const file = await theTestVideo();

    await dragOverPage("dragenter", file);
    assert.dom("[data-test-page-drop]").hasText("Drop to load the video");

    await dragOverPage("drop", file);
    await waitFor("[data-test-duration]");

    assert.dom("[data-test-page-drop]").doesNotExist();
    assert.dom("video").hasAria("label", "ten-seconds.webm");
    assert.dom("[data-test-welcome]").doesNotExist();
  });

  test("during a file drag, the hint is on top of the player", async function (assert) {
    await loadTheTestVideo();

    const file = await theTestVideo();

    await dragOverPage("dragenter", file);

    /**
     * A YouTube player is an iframe, which would take the drag for itself.
     * The hint covers it, so the drop stays on this page.
     */
    const player = find("video");

    if (!player) throw new Error("No video is rendered");

    player.scrollIntoView({ block: "center" });

    const box = player.getBoundingClientRect();
    const top = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);

    assert.dom(top).hasAttribute("data-test-page-drop");

    await dragOverPage("drop", file);
  });

  test("a text file dropped on the page says why it did not load", async function (assert) {
    await visit("/");

    await dragOverPage("drop", new File(["notes"], "notes.txt", { type: "text/plain" }));

    assert.dom("[data-test-drop-error]").hasText("notes.txt is not a video or audio file.");
    assert.dom("[data-test-welcome]").exists();
    assert.dom("video").doesNotExist();

    await dragOverPage("drop", await theTestVideo());
    await waitFor("[data-test-duration]");

    assert.dom("[data-test-drop-error]").doesNotExist("a video that loads clears the message");
  });

  test("a video with no type, as some systems give, still loads", async function (assert) {
    await visit("/");

    const video = await theTestVideo();

    for (const name of ["ten-seconds.mkv", "ten-seconds"]) {
      await dragOverPage("drop", new File([video], name, { type: "" }));
      await waitFor(`video[aria-label="${name}"]`);

      assert.dom("[data-test-drop-error]").doesNotExist(`${name} loads`);
    }
  });

  test("a file from disk plays here", async function (assert) {
    await loadTheTestVideo();

    assert.dom("video").hasAria("label", "ten-seconds.webm");
    assert.dom("[data-test-now]").hasText("0:00.0");
    assert.dom("[data-test-duration]").hasText("0:10.0");
    assert.dom('[aria-label="Loop start"]').hasValue("0");
    assert.dom('[aria-label="Loop end"]').hasValue("10");
    assert.dom("[data-test-loop]").hasAria("pressed", "false");
  });

  test("number keys go back that many seconds", async function (assert) {
    await loadTheTestVideo();
    await seekTo(7, "0:07.0");

    await triggerKeyEvent("[data-test-replay]", "keydown", "3");
    assert.dom("[data-test-now]").hasText("0:04.0");
    assert.strictEqual(video().currentTime, 4);

    await triggerKeyEvent("[data-test-replay]", "keydown", "0");
    assert
      .dom("[data-test-now]")
      .hasText("0:00.0", "0 goes back 10 seconds, and stops at the start");
  });

  test("keys in the link field do not seek", async function (assert) {
    await loadTheTestVideo();
    await seekTo(7, "0:07.0");
    await clickTab("YouTube link");

    await triggerKeyEvent('input[name="link"]', "keydown", "3");
    assert.dom("[data-test-now]").hasText("0:07.0");
  });

  test("the loop plays the part between the markers again and again", async function (assert) {
    await loadTheTestVideo();

    await seekTo(3, "0:03.0");
    await triggerKeyEvent("[data-test-replay]", "keydown", "[");
    await seekTo(4, "0:04.0");
    await triggerKeyEvent("[data-test-replay]", "keydown", "]");

    assert.dom('[aria-label="Loop start"]').hasValue("3");
    assert.dom('[aria-label="Loop end"]').hasValue("4");

    await click("[data-test-loop]");
    assert.dom("[data-test-loop]").hasAria("pressed", "true");

    await triggerKeyEvent("[data-test-replay]", "keydown", "9");
    assert.dom("[data-test-now]").hasText("0:03.0", "going back stops at the loop start");

    await click("[data-test-play]");
    await waitUntil(() => video().currentTime > 3.8, { timeout: 3000 });
    await waitUntil(() => video().currentTime < 3.5, { timeout: 3000 });

    assert.true(video().currentTime >= 3, "the video went back to the loop start");
    assert.false(video().paused, "the video still plays");

    await click("[data-test-play]");
    assert.true(video().paused);
  });

  test("a paused video stays paused at the loop end", async function (assert) {
    await loadTheTestVideo();

    await seekTo(4, "0:04.0");
    await triggerKeyEvent("[data-test-replay]", "keydown", "]");
    await triggerKeyEvent("[data-test-replay]", "keydown", "L");
    assert.dom("[data-test-loop]").hasAria("pressed", "true");

    await new Promise((resolve) => setTimeout(resolve, 500));

    assert.true(video().paused);
    assert.strictEqual(video().currentTime, 4);
    assert.dom("[data-test-play]").hasText("Play");

    await click("[data-test-play]");
    await waitUntil(() => video().currentTime < 1, { timeout: 2000 });
    assert.false(video().paused, "Play starts the loop from its start");

    await click("[data-test-play]");
  });

  test("with the loop on, play starts at the loop start", async function (assert) {
    await loadTheTestVideo();
    await visit("/?loop=1&loop_start=6&loop_end=8");
    assert.strictEqual(video().currentTime, 0, "the video is at its start");

    await click("[data-test-play]");
    await waitUntil(() => video().currentTime >= 6 && !video().paused, { timeout: 2000 });

    assert.true(video().currentTime < 8, "it plays inside the loop");

    await click("[data-test-play]");
  });

  test("with the loop on, play inside the loop stays where it is", async function (assert) {
    await loadTheTestVideo();
    await visit("/?loop=1&loop_start=2&loop_end=8");
    await seekTo(5, "0:05.0");

    await click("[data-test-play]");
    await waitUntil(() => !video().paused, { timeout: 2000 });

    assert.true(video().currentTime >= 5, "it did not jump back to the loop start");

    await click("[data-test-play]");
  });

  test("with the loop off, play starts where the video is", async function (assert) {
    await loadTheTestVideo();
    await visit("/?loop_start=6&loop_end=8");

    await click("[data-test-play]");
    await waitUntil(() => !video().paused, { timeout: 2000 });

    assert.true(video().currentTime < 6, "it did not jump to the loop start");

    await click("[data-test-play]");
  });

  test("the whole video loops when the markers are at its ends", async function (assert) {
    await loadTheTestVideo();
    await click("[data-test-loop]");
    await seekTo(9.5, "0:09.5");
    await click("[data-test-play]");

    await waitUntil(() => video().currentTime < 1 && !video().paused, { timeout: 3000 });
    assert.false(video().paused, "the video plays again from the start");

    await click("[data-test-play]");
  });

  test("the pointer target of each marker is under the marker", async function (assert) {
    await loadTheTestVideo();

    for (const input of document.querySelectorAll<HTMLInputElement>(
      ".replay__markers input[type=range]",
    )) {
      const thumb = input.nextElementSibling;

      if (!thumb) throw new Error("No visual thumb follows the input");

      /**
       * `elementFromPoint` finds only what is in the viewport.
       */
      thumb.scrollIntoView({ block: "center", inline: "center" });

      const visual = thumb.getBoundingClientRect();
      const x = visual.left + visual.width / 2;
      const y = visual.top + visual.height / 2;
      const hit = document.elementFromPoint(x, y) === input ? "hit" : "miss";

      assert.step(`${input.getAttribute("aria-label")} ${hit}`);
    }

    assert.verifySteps(["Loop start hit", "Loop end hit"]);
  });

  test("a marker moves, and the number keys still work from its thumb", async function (assert) {
    await loadTheTestVideo();
    await seekTo(7, "0:07.0");

    await fillIn('[aria-label="Loop end"]', "9.9");
    assert.dom('[aria-label="Loop end"]').hasValue("9.9");
    assert.dom('[aria-label="Loop end"]').hasAria("valuetext", "0:09.9");
    assert.dom('[aria-label="Loop end"]').isFocused();

    await triggerKeyEvent('[aria-label="Loop end"]', "keydown", "3");
    assert.dom("[data-test-now]").hasText("0:04.0");

    await click("[data-test-reset]");
    assert.dom('[aria-label="Loop end"]').hasValue("10", "reset");
  });

  test("the speed goes down and up", async function (assert) {
    await loadTheTestVideo();
    assert.dom("[data-test-rate]").hasText("1×");

    await triggerKeyEvent("[data-test-replay]", "keydown", ">");
    assert.dom("[data-test-rate]").hasText("1.25×");
    assert.strictEqual(video().playbackRate, 1.25);

    await click("[data-test-slower]");
    await click("[data-test-slower]");
    await triggerKeyEvent("[data-test-replay]", "keydown", "<");
    assert.dom("[data-test-rate]").hasText("0.5×");
    assert.strictEqual(video().playbackRate, 0.5);

    await click("[data-test-slower]");
    await click("[data-test-slower]");
    assert.dom("[data-test-rate]").hasText("0.25×", "the speed stops at the slowest");
    assert.dom("[data-test-slower]").hasAria("disabled", "");

    video().playbackRate = 2;
    await waitUntil(() => find("[data-test-rate]")?.textContent === "2×");
    assert.dom("[data-test-faster]").hasAria("disabled", "", "a speed set elsewhere shows too");
  });

  test("the loop shows when it is on", async function (assert) {
    await loadTheTestVideo();

    assert.dom("[data-test-looping]").doesNotExist();
    assert.dom(".replay__markers").doesNotHaveAttribute("data-looping");

    await click("[data-test-loop]");

    assert.dom("[data-test-loop]").hasAria("pressed", "true");
    assert.dom("[data-test-loop]").hasAttribute("data-variant", "primary");
    assert.dom("[data-test-looping]").hasText("Looping 0:00.0 to 0:10.0");
    assert.dom(".replay__markers").hasAttribute("data-looping");
  });

  test("R and the button go to the loop start", async function (assert) {
    await loadTheTestVideo();
    await seekTo(3, "0:03.0");
    await triggerKeyEvent("[data-test-replay]", "keydown", "[");
    await seekTo(8, "0:08.0");

    await triggerKeyEvent("[data-test-replay]", "keydown", "R");
    assert.dom("[data-test-now]").hasText("0:03.0");
    assert.strictEqual(video().currentTime, 3);

    await seekTo(6, "0:06.0");
    await click("[data-test-to-loop-start]");
    assert.dom("[data-test-now]").hasText("0:03.0");
  });

  test("marker moves can be undone and redone", async function (assert) {
    await loadTheTestVideo();
    assert.dom("[data-test-undo]").hasAria("disabled", "");
    assert.dom("[data-test-redo]").hasAria("disabled", "");

    await seekTo(3, "0:03.0");
    await triggerKeyEvent("[data-test-replay]", "keydown", "[");
    await fillIn('[aria-label="Loop end"]', "6");
    await fillIn('[aria-label="Loop end"]', "5");
    assert.dom('[aria-label="Loop start"]').hasValue("3");
    assert.dom('[aria-label="Loop end"]').hasValue("5");

    await triggerKeyEvent("[data-test-replay]", "keydown", "Z", { ctrlKey: true });
    assert.dom('[aria-label="Loop end"]').hasValue("6", "one drag is one step");

    await triggerKeyEvent("[data-test-replay]", "keydown", "Z", { metaKey: true });
    assert.dom('[aria-label="Loop end"]').hasValue("10");

    await click("[data-test-undo]");
    assert.dom('[aria-label="Loop start"]').hasValue("0");
    assert.dom("[data-test-undo]").hasAria("disabled", "");

    await triggerKeyEvent("[data-test-replay]", "keydown", "Z", { ctrlKey: true, shiftKey: true });
    assert.dom('[aria-label="Loop start"]').hasValue("3");

    await click("[data-test-redo]");
    assert.dom('[aria-label="Loop end"]').hasValue("6");

    await click("[data-test-reset]");
    assert.dom("[data-test-redo]").hasAria("disabled", "", "a new move clears redo");

    await triggerKeyEvent("[data-test-replay]", "keydown", "Y", { ctrlKey: true });
    assert.dom('[aria-label="Loop start"]').hasValue("0");

    await click("[data-test-undo]");
    assert.dom('[aria-label="Loop start"]').hasValue("3");
    assert.dom('[aria-label="Loop end"]').hasValue("6");
  });

  test("Ctrl+Z in the link field is for the text", async function (assert) {
    await loadTheTestVideo();
    await seekTo(3, "0:03.0");
    await triggerKeyEvent("[data-test-replay]", "keydown", "[");
    await clickTab("YouTube link");

    await triggerKeyEvent('input[name="link"]', "keydown", "Z", { ctrlKey: true });
    assert.dom('[aria-label="Loop start"]').hasValue("3");
  });

  test("the loop, its markers, and the speed are in the URL", async function (assert) {
    await loadTheTestVideo();
    assert.deepEqual(queryParams(), {}, "the defaults are not in the URL");

    await seekTo(3, "0:03.0");
    await triggerKeyEvent("[data-test-replay]", "keydown", "[");
    await seekTo(4.5, "0:04.5");
    await triggerKeyEvent("[data-test-replay]", "keydown", "]");
    await triggerKeyEvent("[data-test-replay]", "keydown", "L");
    await triggerKeyEvent("[data-test-replay]", "keydown", ">");

    assert.deepEqual(queryParams(), {
      loop_start: "3",
      loop_end: "4.5",
      loop: "1",
      speed: "1.25",
    });

    await triggerKeyEvent("[data-test-replay]", "keydown", "L");
    await triggerKeyEvent("[data-test-replay]", "keydown", "<");
    await click("[data-test-reset]");

    assert.deepEqual(queryParams(), {}, "the defaults leave the URL again");
  });

  test("a burst of changes is one transition", async function (assert) {
    await loadTheTestVideo();

    const router = this.owner.lookup("service:router");

    router.on("routeDidChange", () => assert.step("transition"));

    /**
     * No `await` between the keys, so all three land before the next frame.
     */
    for (const key of ["L", ">", ">"]) {
      document.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true }));
    }

    await settled();

    assert.verifySteps(["transition"]);
    assert.deepEqual(queryParams(), { loop: "1", speed: "1.5" });
  });

  test("a drag of a marker is one change of the URL", async function (assert) {
    await loadTheTestVideo();

    await fillIn('[aria-label="Loop end"]', "6");

    assert.deepEqual(queryParams(), { loop_end: "6" });
  });

  test("the URL sets the loop, its markers, and the speed", async function (assert) {
    await loadTheTestVideo();
    await visit("/?loop_start=2&loop_end=4&loop=1&speed=1.5");

    assert.dom('[aria-label="Loop start"]').hasValue("2");
    assert.dom('[aria-label="Loop end"]').hasValue("4");
    assert.dom("[data-test-loop]").hasAria("pressed", "true");
    assert.dom("[data-test-looping]").hasText("Looping 0:02.0 to 0:04.0");
    assert.dom("[data-test-rate]").hasText("1.5×");

    await waitUntil(() => video().playbackRate === 1.5, { timeout: 1000 });
    assert.strictEqual(video().playbackRate, 1.5, "the video plays at the speed in the URL");
  });

  test("values in the URL that are not times or speeds are ignored", async function (assert) {
    await loadTheTestVideo();
    await visit("/?loop_start=soon&loop_end=-3&speed=9");

    assert.dom('[aria-label="Loop start"]').hasValue("0");
    assert.dom('[aria-label="Loop end"]').hasValue("10");
    assert.dom("[data-test-rate]").hasText("1×");
  });

  test("a YouTube link goes in the URL, and a new video clears the loop", async function (assert) {
    await loadTheTestVideo();
    await visit("/?loop_start=2&loop=1&speed=1.5");
    await clickTab("YouTube link");
    await fillIn('input[name="link"]', "https://youtu.be/dQw4w9WgXcQ");
    await click('button[type="submit"]');

    assert.deepEqual(queryParams(), { youtube_video_id: "dQw4w9WgXcQ", speed: "1.5" });
    assert.dom("video").doesNotExist();
    assert.dom("[data-test-replay]").exists();

    await clickTab("File on disk");
    await triggerEvent(".nvp__file-drop input[type=file]", "change", {
      files: [await theTestVideo()],
    });

    assert.deepEqual(queryParams(), { speed: "1.5" }, "a file is not in the URL");
    assert.dom("video").exists();
  });

  test("a YouTube video id in the URL opens that video", async function (assert) {
    await visit("/?youtube_video_id=dQw4w9WgXcQ");

    assert.dom("[data-test-welcome]").doesNotExist();
    assert.dom("[data-test-replay]").exists();
  });

  test("a YouTube video id that is not one is ignored", async function (assert) {
    await visit("/?youtube_video_id=not-an-id");

    assert.dom("[data-test-welcome]").exists();
  });

  test("a click on the video plays and pauses it", async function (assert) {
    await loadTheTestVideo();

    await click("[data-test-surface]");
    await waitUntil(() => find("[data-test-play]")?.textContent?.trim() === "Pause", {
      timeout: 2000,
    });
    assert.false(video().paused);

    await click("[data-test-surface]");
    await waitUntil(() => find("[data-test-play]")?.textContent?.trim() === "Play", {
      timeout: 2000,
    });
    assert.true(video().paused);
  });

  test("the volume and mute change the video", async function (assert) {
    await loadTheTestVideo();

    await click("[data-test-mute]");
    assert.true(video().muted);
    assert.dom("[data-test-mute]").hasAria("label", "Unmute");
    assert.dom("[data-test-volume]").hasValue("0", "the slider shows silence");

    await triggerKeyEvent("[data-test-replay]", "keydown", "M");
    assert.false(video().muted, "M unmutes");

    await fillIn("[data-test-volume]", "0.5");
    assert.strictEqual(video().volume, 0.5);

    await click("[data-test-mute]");
    await fillIn("[data-test-volume]", "0.3");
    assert.false(video().muted, "moving the volume unmutes");
    assert.strictEqual(video().volume, 0.3);
  });

  test("theatre mode puts the controls over the video", async function (assert) {
    await loadTheTestVideo();
    assert.dom("[data-test-player]").doesNotHaveAttribute("data-overlay");

    await click("[data-test-theatre]");

    assert.dom("[data-test-replay]").hasAttribute("data-theatre");
    assert.dom("[data-test-player]").hasAttribute("data-overlay");
    assert.dom("[data-test-theatre]").hasAria("pressed", "true");
    assert.dom("[data-test-controls]").hasClass("theme-dark");
    assert.dom("[data-test-controls]").hasStyle({ position: "absolute" });

    await triggerKeyEvent("[data-test-replay]", "keydown", "Escape");
    assert.dom("[data-test-replay]").doesNotHaveAttribute("data-theatre", "Escape leaves");

    await triggerKeyEvent("[data-test-replay]", "keydown", "T");
    assert.dom("[data-test-replay]").hasAttribute("data-theatre", "", "T enters");
  });

  test("Escape leaves theatre mode, and T toggles it", async function (assert) {
    await loadTheTestVideo();

    await triggerKeyEvent("[data-test-replay]", "keydown", "T");
    assert.dom("[data-test-theatre]").hasAria("pressed", "true");

    await triggerKeyEvent("[data-test-replay]", "keydown", "T");
    assert.dom("[data-test-theatre]").hasAria("pressed", "false");
    assert.dom("[data-test-player]").doesNotHaveAttribute("data-overlay");

    await click("[data-test-theatre]");
    await triggerKeyEvent("[data-test-replay]", "keydown", "Escape");
    assert.dom("[data-test-replay]").doesNotHaveAttribute("data-theatre");
  });

  test("over the video, the controls hide when nothing happens", async function (assert) {
    await loadTheTestVideo();
    await click("[data-test-theatre]");

    await new Promise((resolve) => setTimeout(resolve, 2800));
    assert.dom("[data-test-player]").doesNotHaveAttribute("data-idle", "paused, they stay");

    await click("[data-test-play]");
    await waitUntil(() => find("[data-test-player]")?.hasAttribute("data-idle"), { timeout: 4000 });
    assert.dom("[data-test-controls]").hasStyle({ pointerEvents: "none" });

    await triggerEvent("[data-test-player]", "pointermove");
    assert.dom("[data-test-player]").doesNotHaveAttribute("data-idle", "a pointer move shows them");

    await triggerEvent("[data-test-controls]", "pointerenter");
    await new Promise((resolve) => setTimeout(resolve, 2800));
    assert
      .dom("[data-test-player]")
      .doesNotHaveAttribute("data-idle", "on the controls, they stay");

    await click("[data-test-play]");
  });

  test("an Instagram link says how to get the file", async function (assert) {
    await visit("/");
    await fillIn(
      'input[name="link"]',
      "https://www.instagram.com/reel/DfFMX-cDtv1/?utm_source=ig_web_copy_link",
    );
    await click('button[type="submit"]');

    assert
      .dom('[role="alert"]')
      .hasText(
        "Instagram does not let other sites control its videos. In the Instagram app, tap Share, then Download. Then drop the file here.",
      );
    assert.dom("[data-test-youtube]").doesNotExist();
  });

  test("a link that is not from YouTube shows an error", async function (assert) {
    await visit("/");
    await fillIn('input[name="link"]', "https://example.com/watch?v=dQw4w9WgXcQ");
    await click('button[type="submit"]');

    assert.dom('[role="alert"]').hasText("That is not a link to a YouTube video.");
    assert.dom('input[name="link"]').hasAria("invalid", "true");
    assert.dom("[data-test-youtube]").doesNotExist();
  });
});
