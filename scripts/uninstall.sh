#!/bin/sh

#
#  uninstall.sh
#  Escrow Buddy
#
#  Copyright 2023 Netflix
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

#  This script uninstalls Escrow Buddy.
echo "Removing Escrow Buddy from authorization database..."
"/Library/Security/SecurityAgentPlugins/Escrow Buddy.bundle/Contents/Resources/AuthDBTeardown.sh" || exit 1

echo "Deleting Escrow Buddy bundle..."
rm -rf "/Library/Security/SecurityAgentPlugins/Escrow Buddy.bundle"

echo "Forgetting receipt..."
pkgutil --forget "com.netflix.Escrow-Buddy" 2>/dev/null

echo "Escrow Buddy successfully uninstalled."
