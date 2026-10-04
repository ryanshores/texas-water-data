# Phase 1.1 alerts and polish

Phase 1.1 is implemented for local development without requiring Apple
Developer Program services.

- Favorite reservoirs have configurable threshold and rapid-change alerts.
  Alerts are evaluated when the app refreshes and delivered as local
  notifications on the device.
- A weekly favorite summary is available in Today and can be delivered as a
  local notification when the app refreshes on Sunday.
- Small, medium, and Lock Screen widget families are supported. Widget taps
  open the relevant reservoir detail where a reservoir is shown; statewide and
  unavailable states open Today.
- The small widget scales its percentage value rather than truncating values
  such as `94.3%`.
- The About tab exposes local notification preferences, data delivery/fallback
  behavior, attribution, methodology, privacy, and API health.

## Deferred until distribution work

Remote APNs delivery, background notification scheduling, and TestFlight/App
Store submission require Apple Developer Program credentials and are intentionally
not part of this local-development update. The notification preferences and
deep-link URL format are designed to be reused when that delivery layer is added.

## Device validation

On a device, enable notifications from About > Notifications, favorite a
reservoir, then refresh Today. Use a favorite in a low/critical/near-full state
or one with a seven-day change of at least two percentage points to validate a
local alert. Tapping the alert or a widget should open that reservoir's detail.
