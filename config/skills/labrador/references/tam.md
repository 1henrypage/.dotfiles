# TAM Reference

TAM (Teaching Assistant Management) handles TA recruitment, contract management, and schedule generation for TU Delft courses.

## Domain Concepts

- **Application** — a student expressing interest to TA for a course edition. Includes availability, preferences.
- **Contract** — an approved agreement for a student to TA. Has hours, pay rate, period.
- **Contract Offer** — a separate contract type for extra work (e.g. grading, exam invigilation). Created by teachers, accepted/rejected by students.
- **Schedule** — auto-generated assignment of TAs to lab sessions. Uses optimization (min-cost max-flow via Gurobi).
- **Eligibility** — whether a student is approved to TA (verified by Education & Student Affairs).

## Workflow

1. **Teacher** registers course on TAM, specifies TA needs
2. **Students** indicate interest + availability for courses
3. **ESA staff** validates student eligibility
4. **Teacher** sends job offers to selected candidates
5. **TAM** auto-generates schedules using Gurobi optimizer
6. **Students** accept/reject contract offers; can retract requests

## Key Technical Details

### LabraCore Integration
TAM fetches from LabraCore:
- Person details, editions, courses
- `removePersonFromEdition` — used when a TA contract is terminated
- Note: LabraCore distinguishes "remove" (unassign) from "block" (prevent re-enrollment)

### Contract Offers (Separate from Regular Contracts)
- Created by teachers via "Add" button next to "Contract Offers" for their course
- Fields: description, hours, pay, deadline
- Students can view offers in "Contract Offers" tab, submit requests
- Teachers approve/reject; students can retract before approval

### Schedule Generation
- Uses Gurobi for optimization (min-cost max-flow problem)
- Constraints: TA availability, course needs, max hours, preferences
- Schedule generation is computationally expensive — may run async

### Permission Model
- Students: view own applications/contracts, accept/reject offers, indicate preferences
- Teachers: manage their course's TAs, create contract offers, view applicants
- ESA: validate eligibility across all courses
- Admin: full access

## Architecture Notes

### Service Layer
TAM services are heavier than other Labrador apps due to scheduling complexity:
```java
@Service
@AllArgsConstructor
public class ContractOfferService {
    private final ContractOfferRepository repository;
    private final PersonControllerApi personApi;
    private final EditionControllerApi editionApi;

    public void createOffer(ContractOfferCreateDTO dto, Long editionId) {
        // validate teacher permission
        // create offer entity
        // notify eligible students
    }
}
```

### Async Operations
Schedule generation and bulk notifications may be `@Async`. Ensure:
- Proper error handling in async methods
- Status tracking (e.g. schedule generation progress)
- Thread pool configuration in application.yml

## Common Tasks

### Adding a Contract Feature
1. Add field to `Contract` or `ContractOffer` entity + migration
2. Update service with validation logic
3. Update controller (thin!)
4. Update Thymeleaf form + display templates
5. Test: mock LabraCore, verify contract state transitions

### Modifying Application Flow
1. Update `ApplicationService`
2. Ensure eligibility checks still work
3. Verify email/notification triggers
4. Test the full flow: apply → validate → offer → accept


