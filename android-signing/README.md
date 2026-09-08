# The signing key

`lip-release.jks.enc` is the LockInPoint release keystore, encrypted with
AES-256 (PBKDF2, 300,000 iterations). It is committed on purpose. The
encrypted file is useless without the passphrase, and the alternative —
holding a 5,900-character base64 blob in a repository secret — has to be
pasted by hand and fails silently when a single character is lost.

## What has to be set, once

Two repository secrets, under **Settings → Secrets and variables → Actions**:

| Secret | What it is |
| --- | --- |
| `ANDROID_KEYSTORE_PASSPHRASE` | 40 characters. Decrypts `lip-release.jks.enc`. |
| `ANDROID_KEYSTORE_PASSWORD` | 32 characters. Opens the keystore itself. |

With both set, every release build is signed with the same key for ever.
With either missing, the build still runs and still produces an installable
APK, but it carries a throwaway debug key and the job summary says so in
capitals. It will not update an existing install and Play will refuse it.

## The key

    alias        lockinpoint
    algorithm    RSA 4096, SHA384withRSA
    valid until  31 August 2056
    SHA-256      6E:89:4D:F3:F6:29:93:1C:66:F3:E0:40:6F:79:6C:78:
                 79:BA:1F:4A:85:6E:18:1E:6C:FD:86:36:74:0C:19:6E

`lockinpoint-upload-certificate.pem` is the public certificate for that key.
A certificate is public by definition — it is what every installed copy of the
app already carries — so it is safe here, and it is the exact file Google Play
asks for if the upload key ever has to be reset.

## If Play rejects the bundle

`com.lockinpoint.app` is already published, so Play already knows an upload
certificate for it. If the first bundle signed with this key comes back with
*"Your Android App Bundle is signed with the wrong key"*, the existing upload
key is a different one and it has to be replaced:

**Play Console → your app → Test and release → Setup → App integrity →
App signing → Request upload key reset**, and attach
`lockinpoint-upload-certificate.pem`. Google action it in a day or two, and
nothing about the installed app changes — Play re-signs every bundle with the
*app signing* key it holds, which is untouched by an upload key reset.

## Never

Do not regenerate this key. Do not change the alias. Android refuses to
install an update signed by a different key, and for a sideloaded APK that
means every student uninstalling and losing everything they downloaded.
