# Native ad bounds regression

Build the Debug simulator app before starting a stopped, dedicated device. Run from the repository root through the shared lifecycle runner:

```sh
python3 ~/.codex/scripts/simulator_session.py --device <OWNED_STOPPED_UDID> --timeout 420 -- python3 Tests/NativeAdLayout/run.py '{device}'
```

The existing DEBUG review route runs the real `PochiNativeAdCard` layout with four widths (280–768pt), four content-size categories (including Accessibility XXXL), and full/missing optional assets. It checks containment, non-overlap, rejection of collapsed bounds and larger required height for larger text. Long Japanese/English advertiser, headline, body and action strings exercise wrapping.

The runner then loads the SDK test ad, confirms registration occurred with fitting asset bounds, and changes the live app to Accessibility XXXL without requesting another ad. It checks the new measured height and font size, and captures the SDK's validator. Screenshots and JSON results are in `Design/NativeAdBoundsReview/`. No ad or call-to-action is clicked. The child restores the original content-size setting; the shared runner shuts down only the owned device.

Diagnostics and synthetic content are compiled only in DEBUG. The production unit and SDK validator configuration are unchanged.
