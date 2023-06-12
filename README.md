# ![Escrow Buddy](images/escrow_buddy_logo_300px.png)

**Escrow Buddy is a macOS authorization plugin that allows MDM administrators to generate and escrow new FileVault personal recovery keys on Macs that lack a valid escrowed key in MDM.**

For more context around the problem of missing FileVault keys in MDM and Escrow Buddy's origin, see [this post on the Netflix Tech Blog](https://netflixtechblog.com/escrow-buddy-an-open-source-tool-from-netflix-for-remediation-of-missing-filevault-keys-in-mdm-815aef5107cd).

---

## Requirements

- Your managed Macs must:
    - be enrolled in an MDM
    - have macOS Mojave 10.14.4 or newer
- Your MDM must:
    - support FileVault recovery key escrow
    - deploy a configuration profile with the [FDERecoveryKeyEscrow](https://developer.apple.com/documentation/devicemanagement/fderecoverykeyescrow) payload
    - have the ability to install packages and run shell scripts

**NOTE**: Escrow Buddy only works with MDM-based escrow solutions, not escrow servers like Crypt Server or Cauliflower Vest.

---

## Deployment

1. **Ensure you have an escrow profile scoped to all Macs** with the [FDERecoveryKeyEscrow](https://developer.apple.com/documentation/devicemanagement/fderecoverykeyescrow) payload.

    This will ensure that any newly generated FileVault recovery key, no matter how it's generated, will be escrowed to your MDM server.

1. Use your MDM to **install the [latest Escrow Buddy installer package](https://github.com/macadmins/escrow-buddy/releases/latest)** on your Macs.

    You can choose to install on all Macs or limit to those that need FileVault recovery keys escrowed.

1. Use your MDM to **run this command** (in root context) on Macs that do not have a valid FileVault recovery key escrowed:

        defaults write /Library/Preferences/com.netflix.Escrow-Buddy.plist GenerateNewKey -bool true

    It is recommended to have this script run dynamically on Macs that need it using your MDM's dynamic scoping feature. See the [Examples](https://github.com/macadmins/escrow-buddy/wiki/Examples) page for examples.

That's it! The next time a FileVault-authorized user logs in to the Mac, a new FileVault personal recovery key will be generated and escrowed to your MDM.

---

## Support

See the wiki for [Frequently Asked Questions](https://github.com/macadmins/escrow-buddy/wiki/FAQ) and [Troubleshooting](https://github.com/macadmins/escrow-buddy/wiki/Troubleshooting) resources.

If you've read those pages and are still having problems, please search our [issues](https://github.com/macadmins/escrow-buddy/issues) (both open and closed) to see whether your issue has already been addressed there. If not, you can [open an issue](https://github.com/macadmins/escrow-buddy/issues/new?template=default.md).

For a faster and more focused response, be sure to provide the following in your issue:

- Log output (see [wiki](https://github.com/macadmins/escrow-buddy/wiki/FAQ#how-do-i-view-escrow-buddys-logs) for information on retrieving logs)
- macOS version you're deploying to
- MDM (name and version) you're using
- What troubleshooting steps you've already taken

---

## Contribution

Contributions are welcome! To contribute, [create a fork](https://github.com/macadmins/escrow-buddy/fork) of this repository, commit and push changes to a branch of your fork, and then submit a [pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request). Your changes will be reviewed by a project maintainer.

---

## Credits

Escrow Buddy was created by the **Netflix Client Systems Engineering** team.

The [Crypt](https://github.com/grahamgilbert/crypt) project was a major inspiration in the creation of this tool — huge thanks to Graham, Wes, and the Crypt team! Jeremy Baker and Tom Burgin's 2015 PSU MacAdmins [session](https://www.youtube.com/watch?v=tcmql5byA_I) on authorization plugins was also a valuable resource.

Escrow Buddy is licensed under the [Apache License, version 2.0](https://www.apache.org/licenses/LICENSE-2.0).
