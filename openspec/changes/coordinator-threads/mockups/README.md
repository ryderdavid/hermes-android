# Coordinator threads mockups

Rendered with the app's real theme (`hermesTheme`, Roboto, Material
Symbols) and real widgets, in two of the golden variants: `dark_blue` and
`light_gold`. 412×892 logical px.

| File | Shows |
|---|---|
| `01_current_*` | Today: one delegated-task card of spinners (the real `GatewaySubagentCard`) |
| `02_coordinator_chat_*` | Coordinator label, threads roster strip, "Started 3 threads" card, chat continuing while threads run |
| `03_threads_sheet_*` | The "All" sheet: slots, stop, earlier threads, pause (gateway-wide), Stop all |
| `04_thread_view_*` | Thread view: task, live tool activity (real `GatewayActivityCard`), steer bar with Stop |
| `05_thread_messages_*` | Phase 2: an update card and an emphasised question card with Reply / Let coordinator decide |
| `06_thread_report_*` | Completion report card with Open thread / Continue, followed by the coordinator's reply |
| `07_coordinator_toggle_*` | Chat menu with the Coordinator mode toggle. The menu is anchored at the top right for the render; in the app it opens from the ⋮ action |
| `08_thread_approval_*` | The real approval sheet raised by a thread, naming it |

The roster chips and tool timestamps use fixed mock data.

## Re-render

```bash
cp openspec/changes/coordinator-threads/mockups/coordinator_mockup_test.dart.txt \
   test/goldens/zz_coordinator_mockup_test.dart
flutter test --update-goldens test/goldens/zz_coordinator_mockup_test.dart
mv test/goldens/mockups/coordinator/*.png openspec/changes/coordinator-threads/mockups/
rm -r test/goldens/zz_coordinator_mockup_test.dart test/goldens/mockups
```
