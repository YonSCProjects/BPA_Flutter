# Hebrew Fonts for BPApp

This directory should contain Hebrew font files for proper RTL support.

## Required Fonts:
- Rubik-Regular.ttf
- Rubik-Bold.ttf  
- Rubik-Medium.ttf

## Font Sources:
- Google Fonts: https://fonts.google.com/specimen/Rubik
- Download the font family and place .ttf files in this directory

## Usage:
The fonts are configured in pubspec.yaml and used in HebrewTheme class for consistent Hebrew typography throughout the app.

## Fallback:
If fonts are not available, the system will use default Hebrew fonts available on the device.