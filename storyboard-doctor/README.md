# storyboard-doctor

Pre-flight an [auto-demo](../../../) storyboard JSON and catch the timing/escaping
mistakes that otherwise cost a full `produce.ts` render to discover.

```bash
storyboard-doctor my-demo.story.json        # run before produce.ts
storyboard-doctor my-demo.story.json --cli-ceiling 12 --rate 2.7
```

It flags, from the storyboard alone:

- **card VO overflow** — a `card:` voiceover whose estimated speech runs longer than the card's `duration` (the "vo part N outruns card" render warning).
- **terminal VO overflow** — a `vhs:` voiceover longer than the ~10.5s a dead-air-trimmed CLI segment actually holds (produce trims inter-command gaps, so `Sleep`s don't lengthen it).
- **captions past the segment** — a `vhs:` caption whose `to` runs past the likely segment end, so it never renders.
- **broken anchors / refs** — a voiceover anchored to a timeline entry that doesn't exist (which makes `produce.ts` fail), a caption on an undefined segment, a timeline pointing at a missing card.
- **risky `Type` lines** — inline JSON / nested quotes + pipes that break the VHS tape parser (feed data from a file instead).

Exit 0 = clean, 1 = problems. Built from a session where these exact issues forced ~10 re-renders; it would have caught them all up front. Pairs with the auto-demo toolkit and `claude-fleet`.

Tests: `./test_storyboard_doctor.sh` (10/10).

MIT © deemwar
