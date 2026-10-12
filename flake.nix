{
  description = "Toolchain for building the Audiobookshelf Android app";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # Build a debug APK:
  #   nix develop
  #   npm ci
  #   npm run generate && npx cap sync android
  #   (cd android && ./gradlew assembleDebug)
  #   adb install -r android/app/build/outputs/apk/debug/app-debug.apk
  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };
      android = pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "36" "35" ];
        buildToolsVersions = [ "35.0.0" ];
        includeNDK = false;
        includeEmulator = false;
      };
      sdk = "${android.androidsdk}/libexec/android-sdk";
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.nodejs_22
          pkgs.jdk21
          pkgs.android-tools
        ];
        ANDROID_HOME = sdk;
        ANDROID_SDK_ROOT = sdk;
        # Capacitor 7 compiles for Java 21
        JAVA_HOME = pkgs.jdk21.home;
        # Nuxt 2's webpack 4 needs the legacy OpenSSL provider on Node 17+
        NODE_OPTIONS = "--openssl-legacy-provider";
        # The aapt2 Gradle downloads from Maven does not run on NixOS; use the SDK's.
        # The app module pins a JDK 17 toolchain, so hand Gradle both JDKs.
        GRADLE_OPTS = builtins.concatStringsSep " " [
          "-Dorg.gradle.project.android.aapt2FromMavenOverride=${sdk}/build-tools/35.0.0/aapt2"
          "-Dorg.gradle.java.installations.paths=${pkgs.jdk17.home},${pkgs.jdk21.home}"
          "-Dorg.gradle.java.installations.auto-download=false"
        ];
      };
    };
}
