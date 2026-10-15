# Releasing

Cutting a release of the `voikko` gem, `0.2.0` standing in for the new version.

1. **Master is green:** `bundle exec rake check` passes locally, and CI passes on the commit you
   are about to release.
2. **README is current:** its Usage section shows the main happy path, with each major
   capability in the `[Unreleased]` CHANGELOG lines at least once. Secondary calls
   (`#language`, `.library_version`, `#closed?`, `Error`) and per-symbol detail are left to
   the yardoc on rubydoc.info.
3. **Bump the version** in `lib/voikko/version.rb`.
4. **`bundle install`**, so `Gemfile.lock` records the new version — CI installs from the
   lockfile frozen and fails on a stale one.
5. **`CHANGELOG.md`:** rename `## [Unreleased]` to `## [0.2.0] - <YYYY-MM-DD>` and open a fresh,
   empty `## [Unreleased]` above it.
6. **Commit** the three files: `Release 0.2.0`.
7. **`bundle exec rake release`** — builds `pkg/voikko-0.2.0.gem`, tags `v0.2.0`, pushes the
   commit and the tag, and pushes the gem to rubygems.org. It refuses a dirty tree; it prompts
   for an OTP (the gemspec sets `rubygems_mfa_required`). On a new machine, `gem signin` first,
   in your own terminal: answer **y** to `push_rubygem` (it defaults to No) and leave the gem
   scope blank, or the push fails with "This API key cannot perform the specified action on
   this gem". `rake release` pushes git before the gem, so after such a failure fix the key
   (`gem signout`, `gem signin`) and finish with `gem push pkg/voikko-0.2.0.gem`.
8. **GitHub release**, its notes the version's CHANGELOG lines copied by hand:

   ```
   gh release create v0.2.0 --verify-tag --title 0.2.0 --notes "<the 0.2.0 CHANGELOG lines>"
   ```

9. **Verify:** https://rubygems.org/gems/voikko lists the version and the libvoikko requirement;
   `gem install voikko` works in a clean shell; https://rubydoc.info/gems/voikko renders the new
   yardoc (it picks new versions up on its own).
