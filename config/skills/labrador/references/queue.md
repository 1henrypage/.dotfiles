# Queue Reference

Queue is a digital queueing system for handling practical (lab) sessions in higher education.
Students enqueue for help during lab sessions; TAs dequeue and assist them. Supports in-person and video (Jitsi).

## Domain Concepts

- **Lab** — a scheduled practical session for a course edition. Has a room, time slot, and assigned TAs.
- **QueueEntry** — a student (or group) waiting for help. Contains position, enqueue time, description of question.
- **TA Session** — a TA's active presence in a lab. Tracks which students they've helped.
- **Student Group** — pulled from LabraCore. Students enqueue as their group if the course uses group work.
- **Jitsi Link** — auto-generated video call link for remote TA sessions.

## Key Technical Details

### LabraCore Integration
Queue fetches from LabraCore:
- Editions, courses, cohorts, student groups, person details
- Uses LabraDoor `ControllerApi` beans — all mocked in tests

Common issue: Students without a student group cannot enqueue for group-based labs. Queue should handle this gracefully (show helpful error or auto-create individual group).

### Caching
Queue uses caching heavily for LabraCore data (editions, courses) to reduce API calls.
- `EditionCache`, `CourseCache` — register data from LabraCore responses
- Cache is populated eagerly on edition list pages

### Real-Time Updates
Queue likely uses WebSocket or SSE for live queue position updates.
When modifying queue state, ensure real-time subscribers are notified.

### Permission Model
- Students can only enqueue in labs they're enrolled in
- TAs can only dequeue in labs they're assigned to
- Teachers/admins have full access to their edition's labs
- Permission checks via `@PreAuthorize("@permissionService.canXxx(#id)")`

## Architecture Notes

### Controller Pattern (Queue-Specific)
Queue controllers often need to combine local data with LabraCore data. Pattern:

```java
@GetMapping("/editions")
public String getEditionList(@AuthenticatedPerson Person person, Model model) {
    List<EditionDetailsDTO> editions = editionService.getEditions(person);
    // Filter, convert to QueueEditionDetailsDTO, paginate...
    model.addAttribute("editions", page);
    return "edition/index";
}
```

Keep the logic in the service, not the controller.

### QueueEditionDTO Pattern
Queue often wraps LabraCore DTOs with additional queue-specific fields:
```java
public class QueueEditionDetailsDTO extends EditionDetailsDTO {
    private boolean hidden;
    private int activeLabs;
    // queue-specific fields
}
```

## Common Tasks

### Adding a Lab Feature
1. Add field to `Lab` entity + Liquibase migration
2. Update `LabService` with business logic
3. Update controller (keep it thin)
4. Update Thymeleaf template
5. Test: mock LabraCore APIs, verify lab state changes

### Modifying Enqueue Logic
1. Update `QueueService.enqueue()` or equivalent
2. Handle edge cases: no student group, lab full, student already in queue
3. Ensure real-time update is triggered
4. Test both happy path and error cases

### Filtering/Pagination
Queue uses `PageUtil.toPage()` for manual pagination of lists:
```java
var page = PageUtil.toPage(pageable, items, Comparator.comparing(Item::getId));
```
