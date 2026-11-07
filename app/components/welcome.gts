import type { TOC } from "@ember/component/template-only";

/**
 * The mascot: a very happy TV, in kawaii pink.
 * In dark mode it goes goth: the colors come from CSS,
 * and the `--goth` parts show in place of the `--cute` ones.
 *
 * It bobs, blinks, and sparkles. Under `prefers-reduced-motion`, it holds still.
 */
const HappyTv: TOC<{ Element: SVGSVGElement }> = <template>
  <svg viewBox="0 0 200 175" aria-hidden="true" ...attributes>
    <g class="tv-sparkles">
      <path
        class="welcome__sparkle welcome__cute"
        d="M24 33Q24 42 33 42Q24 42 24 51Q24 42 15 42Q24 42 24 33Z"
      />
      <path class="tv-moon welcome__goth" d="M30 28a13 13 0 1 0 13 17a10 10 0 1 1-13-17Z" />
      <path
        class="welcome__sparkle welcome__sparkle--late"
        d="M182 27Q182 34 189 34Q182 34 182 41Q182 34 175 34Q182 34 182 27Z"
      />
      <path
        class="welcome__sparkle welcome__sparkle--later"
        d="M178 116Q178 126 188 126Q178 126 178 136Q178 126 168 126Q178 126 178 116Z"
      />
      <path
        class="welcome__sparkle welcome__sparkle--late"
        d="M18 126Q18 132 24 132Q18 132 18 138Q18 132 12 132Q18 132 18 126Z"
      />
    </g>

    <g class="tv-floaters welcome__cute">
      <path
        class="welcome__heart"
        d="M178 87.4C169.6 82.6 174.4 76 178 80.2C181.6 76 186.4 82.6 178 87.4Z"
      />
      <path
        class="welcome__heart welcome__heart--late"
        d="M22 100.5C15 96.5 19 91 22 94.5C25 91 29 96.5 22 100.5Z"
      />
    </g>

    <g class="tv-floaters welcome__goth">
      <path class="welcome__heart" d={{bat 178 84}} />
      <path class="welcome__heart welcome__heart--late" d={{bat 22 97}} />
    </g>

    <g class="welcome__bob">
      <rect class="tv-shade" x="56" y="140" width="18" height="22" rx="9" />
      <rect class="tv-shade" x="126" y="140" width="18" height="22" rx="9" />

      <path class="tv-antenna" d="M86 52 72 26M114 52 128 26" />
      <path class="tv-accent" d="M70 28.1C57.4 20.9 64.6 11 70 17.3C75.4 11 82.6 20.9 70 28.1Z" />
      <path
        class="tv-accent"
        d="M130 28.1C117.4 20.9 124.6 11 130 17.3C135.4 11 142.6 20.9 130 28.1Z"
      />

      <rect class="tv-body" x="30" y="48" width="140" height="104" rx="30" />
      <rect class="tv-top" x="36" y="52" width="128" height="40" rx="22" />
      <rect class="tv-screen" x="44" y="60" width="112" height="74" rx="22" />
      <path class="tv-glare" d="M54 76q5-8 16-9" />

      <g class="welcome__eyes">
        <ellipse class="tv-ink" cx="78" cy="96" rx="12" ry="14" />
        <ellipse class="tv-ink" cx="122" cy="96" rx="12" ry="14" />
        <circle class="tv-shine" cx="82" cy="90" r="5" />
        <circle class="tv-shine" cx="126" cy="90" r="5" />
        <path
          class="tv-shine"
          d="M74 99.5Q74 102 76.5 102Q74 102 74 104.5Q74 102 71.5 102Q74 102 74 99.5Z"
        />
        <path
          class="tv-shine"
          d="M118 99.5Q118 102 120.5 102Q118 102 118 104.5Q118 102 115.5 102Q118 102 118 99.5Z"
        />
        <path class="tv-lashes" d="M67 88 61 83M66 95 59 94M133 88 139 83M134 95 141 94" />
        <path class="tv-liner welcome__goth" d="M90 87q-12-12-24 3l-7-5M110 87q12-12 24 3l7-5" />
      </g>

      <ellipse class="tv-blush" cx="60" cy="114" rx="10" ry="6" />
      <ellipse class="tv-blush" cx="140" cy="114" rx="10" ry="6" />
      <path
        class="tv-blush-lines"
        d="M55 117l2-5M60 117l2-5M65 117l2-5M135 117l2-5M140 117l2-5M145 117l2-5"
      />

      <ellipse class="tv-tongue welcome__cute" cx="100" cy="116" rx="4" ry="3.5" />
      <path class="tv-fang welcome__goth" d="M93 111.5 95.75 119 98.5 111.5Z" />
      <path class="tv-mouth" d="M91 110q4.5 6 9 0q4.5 6 9 0" />

      <circle class="tv-knob" cx="56" cy="143" r="4" />
      <circle class="tv-knob" cx="68" cy="143" r="4" />
      <path
        class="tv-accent"
        d="M141 146.5C134 142.5 138 137 141 140.5C144 137 148 142.5 141 146.5Z"
      />

      <path class="tv-bow" d="M152 50 136 40q-4 10 0 20Z" />
      <path class="tv-bow" d="M152 50 168 40q4 10 0 20Z" />
      <circle class="tv-accent" cx="152" cy="50" r="5.5" />
    </g>
  </svg>
</template>;

/**
 * A little bat, centered on `x`, `y`.
 */
function bat(x: number, y: number) {
  return (
    `M${x} ${y + 3}c-2-3-5-3-8-1c1-3 0-5-2-7c3 0 6 2 7 4c0-2 1-3 2-4c0 1 0 1 1 1c1 0 1 0 1-1` +
    `c1 1 2 2 2 4c1-2 4-4 7-4c-2 2-3 4-2 7c-3-2-6-2-8 1Z`
  );
}

export const Welcome: TOC<object> = <template>
  <section class="welcome" aria-labelledby="welcome-title" data-test-welcome>
    <HappyTv class="welcome__art" />

    <div class="welcome__text">
      <h2 id="welcome-title">Pick a video to start</h2>
      <p>Paste a YouTube link, or drop a video file anywhere on this page.</p>
      <p class="welcome__why">
        Why only these two? So the app needs no server and no permissions. A file plays from your
        disk and is never uploaded. A YouTube link plays in YouTube's own player.
      </p>
    </div>
  </section>
</template>;
