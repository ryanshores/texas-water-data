# Phase 1 release checklist

The production data path is live and historical observations have been
backfilled. Run this checklist on a signed device or internal TestFlight build
before starting alerts work.

## Data and network

- [ ] Today shows `Source: Texas Water API` after a fresh launch.
- [ ] A reservoir detail chart contains the backfilled one-year range and its
      newest point matches the displayed observation date.
- [ ] Pull to refresh updates the source timestamp without losing favorites.
- [ ] With networking disabled, the app starts from cached data and labels the
      source as offline cache or reports the saved-data state.
- [ ] With the API URL temporarily invalid, the app falls back to Water Data
      for Texas and remains usable.
- [ ] Re-enable networking and confirm the app returns to the Texas Water API
      source on refresh.

## Widgets and shared storage

- [ ] Add a favorite in the app and confirm it appears in the widget.
- [ ] Refresh the widget and confirm it shows either current or cached data.
- [ ] Remove the favorite in the app and confirm the widget no longer shows it.
- [ ] Confirm both app and widget are signed with the
      `group.com.ryanshores.TexasWater` App Group entitlement.

## Accessibility and layout

- [ ] VoiceOver can identify source, freshness, percent-full status, and trend
      direction without relying on color.
- [ ] Dynamic Type at the largest accessibility size does not clip dashboard
      cards, charts, basin rows, or the About screen.
- [ ] Reduce Transparency and Increase Contrast preserve readable status cues.
- [ ] Map markers have accessible labels and the reservoir list remains usable
      when map content is unavailable.

## Release metadata

- [ ] Confirm TWDB attribution and methodology links open successfully.
- [ ] Confirm the privacy description matches the shipped behavior: no account,
      no precise location, and favorites/cache stored locally.
- [ ] Record the build number and backend source timestamp for the internal
      TestFlight notes.
