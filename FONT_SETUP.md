# Font Setup Instructions

## Montserrat Font Files Required

The app is configured to use local Montserrat font files to avoid network connectivity issues. You need to replace the placeholder files in `assets/fonts/` with actual Montserrat font files.

## Required Font Files:

1. **Montserrat-Regular.ttf** (Weight: 400)
2. **Montserrat-Medium.ttf** (Weight: 500) 
3. **Montserrat-SemiBold.ttf** (Weight: 600)
4. **Montserrat-Bold.ttf** (Weight: 700)

## Where to Download:

### Option 1: Google Fonts
1. Visit [Google Fonts Montserrat](https://fonts.google.com/specimen/Montserrat)
2. Click "Download family"
3. Extract the ZIP file
4. Copy the required weight files to `assets/fonts/`

### Option 2: GitHub
1. Visit [Montserrat GitHub Repository](https://github.com/JulietaUla/Montserrat)
2. Navigate to the `fonts/ttf` directory
3. Download the required weight files
4. Copy them to `assets/fonts/`

## Installation Steps:

1. Download the Montserrat font files using one of the options above
2. Replace the placeholder files in `assets/fonts/` with the actual font files
3. Ensure the file names match exactly:
   - `Montserrat-Regular.ttf`
   - `Montserrat-Medium.ttf`
   - `Montserrat-SemiBold.ttf`
   - `Montserrat-Bold.ttf`
4. Run `flutter clean` and then `flutter pub get`
5. Restart your app

## Configuration

The fonts are already configured in `pubspec.yaml` under the `fonts` section. No additional configuration is needed once you replace the files.

## Troubleshooting

If fonts don't load properly:
1. Ensure file names match exactly (case-sensitive)
2. Verify files are in the correct directory: `assets/fonts/`
3. Run `flutter clean` and rebuild
4. Check that the font files are valid TTF files 