"""Run after `flutter create ... .`; configures generated mobile files.

Requires only Python 3 standard library. Safe to run repeatedly.
"""
from pathlib import Path
import plistlib
import re
import shutil
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent


def configure_android():
    destination = ROOT / 'android/app/src/main/AndroidManifest.xml'
    if not destination.parent.exists():
        raise SystemExit('Android project not generated. Run flutter create first.')
    source = ROOT / 'templates/android/AndroidManifest.xml'
    ET.parse(source)  # Validate, even with the Gradle ${applicationName} placeholder.
    shutil.copyfile(source, destination)
    gradle = ROOT / 'android/app/build.gradle.kts'
    if gradle.exists():
        data = gradle.read_text(encoding='utf-8')
        data = data.replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
        gradle.write_text(data, encoding='utf-8')
    else:
        gradle = ROOT / 'android/app/build.gradle'
        if gradle.exists():
            data = gradle.read_text(encoding='utf-8')
            data = data.replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 24')
            gradle.write_text(data, encoding='utf-8')
    print('Android: WhatsApp share target, internet permission, minSdk 24 configured.')


def configure_ios():
    plist_path = ROOT / 'ios/Runner/Info.plist'
    if not plist_path.exists():
        print('iOS project not generated yet. Run setup on a Mac for an iOS build.')
        return
    with plist_path.open('rb') as file:
        plist = plistlib.load(file)
    plist['AppGroupId'] = '$(CUSTOM_GROUP_ID)'
    desired_scheme = 'ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)'
    schemes = plist.setdefault('CFBundleURLTypes', [])
    if not any(desired_scheme in entry.get('CFBundleURLSchemes', []) for entry in schemes):
        schemes.append({'CFBundleTypeRole': 'Editor', 'CFBundleURLSchemes': [desired_scheme]})
    with plist_path.open('wb') as file:
        plistlib.dump(plist, file, sort_keys=False)
    podfile = ROOT / 'ios/Podfile'
    if podfile.exists():
        data = podfile.read_text(encoding='utf-8')
        data = re.sub(r"^\s*#?\s*platform :ios, '[^']+'", "platform :ios, '15.6'", data, count=1, flags=re.MULTILINE)
        if "platform :ios, '15.6'" not in data:
            data = "platform :ios, '15.6'\n" + data
        podfile.write_text(data, encoding='utf-8')
    pbx = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
    if pbx.exists():
        data = pbx.read_text(encoding='utf-8')
        data = re.sub(r'(IPHONEOS_DEPLOYMENT_TARGET = )\d+(?:\.\d+)*;', r'\g<1>15.6;', data)
        pbx.write_text(data, encoding='utf-8')
    print('iOS: minimum iOS 15.6, share extension app group/url info configured.')
    print('iOS: add a Share Extension in Xcode and configure App Groups as in README.')


if __name__ == '__main__':
    configure_android()
    configure_ios()
