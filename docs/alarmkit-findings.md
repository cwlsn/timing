# AlarmKit timers on a real phone

What a small test app showed, kept because the answers shape this app. The test app was removed once it had answered them.

iPhone 14 Pro, November 25, 2026. One run of each test, phone unlocked.

| Question | Answer |
|---|---|
| Add time with the app closed | Works, 3 rounds. iOS launches the app to run the intent. |
| Repeat with the app closed | Works, 3 rounds. |
| Are later rings visible? | Yes, with a second button, every round. |
| Does pausing keep the time? | Yes. 29 seconds were left 10 seconds later, and it resumed from there. |
| Can the app read the time left? | Yes, from the Live Activity's content state, running and paused. |
| Two rings at once | Shown one at a time. Stopping the first shows the second, still alerting. |
| Does `stop(id:)` from the app run the stop intent? | No. |
| Alarm limit | Not reached at 100 one-hour timers. |

While unlocked, the ring shows only symbols: plus or repeat, and a cross. Button text such as "Add 5m" does not appear.

## Checked by hand with Timing itself

Same phone and day, reported as working:

- Three timers in the Dynamic Island and on the Lock Screen, with Pause and Stop. The test app's Dynamic Island had been empty in a screenshot; Timing's is not.
- A ring on a locked phone in Silent mode with the app closed, and Add time and Repeat from it.
- Starting a timer with the app closed from the Home Screen widget, the Lock Screen widget, Control Center and Siri.

## Not tested

A restart or a clock change while a timer runs.
