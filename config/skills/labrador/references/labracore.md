# LabraCore Reference

LabraCore is the central shared database and REST API for the entire Labrador ecosystem.
All other apps (Queue, TAM, GitBull, etc.) consume LabraCore data via LabraDoor.

## Core Entities

LabraCore manages these primary entities (and their relationships):

- **Person** — any user (student, teacher, admin). Linked via TU Delft NetID/SSO.
- **Course** — a course offering (e.g. "Object Oriented Programming", code "CSE1100"). Belongs to a Programme.
- **Programme** — degree programme (e.g. "BSc Computer Science and Engineering").
- **Edition** — a specific run of a course in an academic period. Has start/end dates, teachers, TAs.
- **Cohort** — a group of students within an edition.
- **Assignment** — coursework within an edition.
- **StudentGroup** — groups of students for collaborative work.
- **Role / DefaultRole** — permission roles (STUDENT, TEACHER, ADMIN, etc.).

## API Structure

LabraCore exposes REST endpoints under `/api/` for each entity. Examples:
- `GET /api/course` — all courses
- `GET /api/course/{id}` — course details
- `POST /api/course` — create course
- `GET /api/edition/{id}` — edition details
- `GET /api/person/{id}` — person details

Other apps never call these directly — they use LabraDoor's `<Entity>ControllerApi` beans.

## Architecture Patterns

### Adding a New Entity to LabraCore

1. Create the `@Entity` class in `model/`
2. Create the `JpaRepository` in `repository/`
3. Create DTOs: `<Entity>SummaryDTO`, `<Entity>DetailsDTO`, `<Entity>CreateDTO`
4. Create the `@Service` class
5. Create the `@RestController` under `controller/api/`
6. Add Liquibase migration in `src/main/resources/db/changelog/`
7. Update LabraDoor's generated API client (if other apps need access)

### DTO Conventions

LabraCore uses a consistent DTO naming pattern:
- `<Entity>SummaryDTO` — lightweight, for list views (ID + essential fields)
- `<Entity>DetailsDTO` — full details, for detail views (includes nested relations)
- `<Entity>CreateDTO` — input for creation endpoints
- `<Entity>UpdateDTO` — input for update endpoints (when different from create)

### Permission Model

LabraCore tracks roles per person per edition:
- A person can be STUDENT in one edition and TEACHER in another.
- `removePersonFromEdition` vs `blockPersonFromEdition` — remove just unassigns; block prevents re-enrollment.
- Permissions are checked via `@PreAuthorize` annotations referencing a `PermissionService`.

## Running Locally

```bash
# Clone and setup
git clone git@gitlab.ewi.tudelft.nl:eip/labrador/labracore.git
cd labracore
cp src/main/resources/application.template.yml src/main/resources/application.yml

# Build and run
./gradlew clean assemble
java -jar build/libs/labracore-*.jar
```

LabraCore runs on **port 8082** by default.

## Common Tasks

### Adding a Field to an Existing Entity
1. Add field to entity class
2. Add Liquibase `addColumn` changeset
3. Update relevant DTOs
4. Update service if field has business logic
5. Update tests

### Exposing a New Endpoint
1. Add method to the appropriate `@RestController`
2. Add `@PreAuthorize` if needed
3. Ensure the DTO exists or create one
4. Write integration test that verifies HTTP status + response body
5. If other apps need this endpoint: update LabraDoor API client generation
