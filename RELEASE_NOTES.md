<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->
# azure-chef-extension 1210.12.105.1001 release notes:
In this release, we have fixed the issue where if the validation key is base64 encoded using powershell, the `validation.pem` creation fails.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension

##Issues fixed in azure-chef-extension 1210.12.105.1001
* Fix for validation.pem file not generating [Issue 157](https://github.com/chef-partners/azure-chef-extension/issues/157)
