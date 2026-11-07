import { module, test } from "qunit";

import { isInstagramLink } from "#utils/instagram.ts";

module("Unit | isInstagramLink", function () {
  const yes: [string, string][] = [
    ["https://www.instagram.com/reel/DfFMX-cDtv1/?utm_source=ig_web_copy_link", "a reel link"],
    ["https://www.instagram.com/p/DfFMX-cDtv1/", "a post link"],
    ["instagram.com/reel/DfFMX-cDtv1", "a link without the protocol"],
    ["https://instagr.am/p/DfFMX-cDtv1", "a short link"],
  ];

  for (const [input, name] of yes) {
    test(`knows ${name}`, function (assert) {
      assert.true(isInstagramLink(input));
    });
  }

  const no: [string, string][] = [
    ["https://www.youtube.com/watch?v=dQw4w9WgXcQ", "a YouTube link"],
    ["https://notinstagram.com/reel/x", "another site"],
    ["", "an empty string"],
  ];

  for (const [input, name] of no) {
    test(`rejects ${name}`, function (assert) {
      assert.false(isInstagramLink(input));
    });
  }
});
