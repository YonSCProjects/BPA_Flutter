@echo off
echo Generating SHA-1 and SHA-256 certificates for Google OAuth...
echo.

echo Trying default debug keystore location...
keytool -list -v -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -keypass android

echo.
echo If the above failed, trying alternative location...
keytool -list -v -alias androiddebugkey -keystore "%LOCALAPPDATA%\Android\Sdk\.android\debug.keystore" -storepass android -keypass android

echo.
echo If both failed, you can manually create the debug keystore with:
echo keytool -genkey -v -keystore debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000

pause