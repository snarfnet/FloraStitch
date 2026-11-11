# Flora Stitch

Flora Stitch is a SwiftUI iOS prototype for generating original floral embroidery borders.

## Current Scope

- Seeded random floral border generation
- Vine, leaf, flower, berry, and curl elements
- Live SwiftUI canvas preview
- Controls for width, density, flower mix, curls, and palette
- SVG export
- DST export from generated stitch points
- Experimental PES payload export

## Build

This project follows the workspace's XcodeGen pattern.

```bash
cd ios/FloraStitch
xcodegen generate
open FloraStitch.xcodeproj
```

## Notes On Embroidery Formats

DST export writes a Tajima-style stitch stream with color-change records. It is suitable for early machine and converter testing, but real production output still needs test stitching and tuning for fabric, thread, needle, and hoop size.

PES export is intentionally marked experimental. Brother PES is a larger container format with version-specific blocks, thumbnails, color tables, and stitch sections. The app already keeps the same stitch plan needed for a full PES writer, so the next step is replacing the payload writer with a full PES encoder.

## Next Steps

- Add PNG transparent export
- Add stitch preview modes: running stitch, satin fill, and bean stitch
- Add underlay and jump-trim controls
- Add true PES v1/v6 encoder
- Add saved favorites by seed
- Add repeat, corner, wreath, and frame layout modes
