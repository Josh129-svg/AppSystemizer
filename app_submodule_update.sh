git submodule deinit system
git rm -r -q --cached system
rm -rf system/
rm -rf .git/modules/system/
git add .; git commit -m "remove companion app submodule"; git push -f
git submodule -q add git@github.com:loserskater/AppSystemizer-companion.git system
git config -f .gitmodules system.latest-apk latest-apk
git -C system checkout -q latest-apk
git add .; git commit -q -m "update companion app submodule"; git push -q -f
