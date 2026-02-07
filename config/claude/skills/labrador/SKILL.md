---
name: labrador
description: >
  Skill for working on the Labrador suite of Spring Boot educational software at TU Delft EIP.
  Covers: LabraCore (central API/database), Librador (shared library), Queue (lab session queueing),
  TAM (teaching assistant management), and GitBull (GitLab management). Use when writing features,
  services, controllers, repositories, tests, migrations, or reviewing code for any Labrador repo.
  Triggers on mentions of: labracore, librador, labradoor, queue, tam, gitbull, labrador,
  or any EIP/TU Delft educational software development task involving Spring Boot + Thymeleaf + Gradle.
---

# Labrador Development Skill

## Ecosystem Overview

Labrador is a suite of Spring Boot applications for educational software at TU Delft EEMCS.

| Component | Purpose | Repo |
|-----------|---------|------|
| **LabraCore** | Central shared database/API — courses, editions, people, assignments | `eip/labrador/labracore` |
| **Librador** | Shared Java library — common DTOs, utilities, config adapters | `eip/labrador/librador` |
| **LabraDoor** | Auth library — handles inter-service communication with LabraCore | `eip/labrador/labradoor` |
| **Queue** | Digital queueing for lab sessions, supports Jitsi video links | `eip/labrador/queue` |
| **TAM** | TA recruitment, contracts, scheduling (uses Gurobi optimizer) | `eip/labrador/tam` |
| **GitBull** | GitLab repo management, student group repos, statistics | `eip/labrador/gitbull` |

## Per-Repo References

Load the appropriate reference file based on which repo is being worked on:

- **LabraCore**: See [references/labracore.md](references/labracore.md)
- **Queue**: See [references/queue.md](references/queue.md)
- **TAM**: See [references/tam.md](references/tam.md)
- **GitBull**: See [references/gitbull.md](references/gitbull.md)

If a task spans multiple repos (e.g. adding an entity to LabraCore + consuming it in Queue), load all relevant references.

## Tech Stack (All Repos)

- **Language**: Java 21 
- **Framework**: Spring Boot (Web, Security, Data JPA, Webflux for LabraDoor calls)
- **Build**: Gradle (Kotlin DSL — `build.gradle.kts`)
- **Frontend**: Thymeleaf templates with server-side rendering
- **Database**: PostgreSQL (prod), H2 (dev/test), Liquibase migrations
- **Auth**: SAML2 SSO via LabraDoor, in-memory auth for dev
- **Testing**: JUnit 5, Mockito, Spring Boot Test, MockMvc
- **CI/CD**: GitLab CI on `gitlab.ewi.tudelft.nl`
- **Package registry**: Maven packages hosted on TU Delft GitLab

## Style Guide (Enforced Across All Repos)

### Controllers
- Depend ONLY on services or mid-level beans — never on repositories, cache managers, or `ControllerApi` directly.
- Methods must not exceed 5 lines of logic. Model attribute additions and return statements don't count.
- If a method exceeds 20 lines total, combine model attributes into a DTO.

### Services
- May depend on other services but must form a **directed acyclic graph** (no circular deps).
- May NOT depend on controllers.
- All LabraCore API calls go through `<Entity>ControllerApi` beans (provided by LabraDoor).
- API calls return `Mono` (single) or `Flux` (multiple) — use `.block()` / `.collectList().block()`.

### Repositories
- Long JPA method names must have a `default` readable wrapper or use `@Query` with a simple name.

```java
// Good: wrapper
List<Edition> findAllByIdInAndStartDateAfterAndEndDateBefore(Set<Long> ids, LocalDateTime start, LocalDateTime end);
default List<Edition> findEditionsBetween(Set<Long> ids, LocalDateTime start, LocalDateTime end) {
    return findAllByIdInAndStartDateAfterAndEndDateBefore(ids, start, end);
}

// Also good: @Query
@Query("select e from Edition e where e.id in ?1 and e.startDate > ?2 and e.endDate < ?3")
List<Edition> findEditionsBetween(Set<Long> ids, LocalDateTime start, LocalDateTime end);
```

### DTOs
- Pure data only. No business logic.
- If constructing a DTO requires a service/repository call, do it in a service method.

### Thymeleaf
- Never call expensive bean methods from templates — precalculate in the controller.
- Use `th:unless` for else-conditions, not `th:if="${not condition}"`.

## Writing Features — Standard Pattern

### 1. Entity + Repository
```java
@Entity
@Getter @Setter
@NoArgsConstructor
public class MyEntity {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    // fields...
}

public interface MyEntityRepository extends JpaRepository<MyEntity, Long> { }
```

### 2. Service
```java
@Service
@AllArgsConstructor
public class MyEntityService {
    private final MyEntityRepository repository;

    public MyEntity getRequired(Long id) {
        return repository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
    }
}
```

### 3. Controller
```java
@Controller
@AllArgsConstructor
@RequestMapping("my-entity")
public class MyEntityController {
    private final MyEntityService myEntityService;

    @GetMapping("/{id}")
    public String getPage(@PathVariable Long id, Model model) {
        model.addAttribute("entity", myEntityService.getRequired(id));
        return "my-entity/view";
    }
}
```

### 4. Thymeleaf Template
```html
<!DOCTYPE html>
<html lang="en" xmlns:th="http://www.thymeleaf.org"
      xmlns:layout="http://www.ultraq.net.nz/thymeleaf/layout"
      layout:decorate="~{layout}">
<head><title>My Entity</title></head>
<body>
<th:block layout:fragment="content">
    <h1 th:text="${entity.name}"></h1>
</th:block>
</body>
</html>
```

## Writing Tests

### Integration Tests
```java
@Transactional
@SpringBootTest(classes = TestApplication.class)
public class MyServiceIntegrationTest {

    @Autowired private MyService myService;
    @Autowired private CourseControllerApi courseApi; // auto-mocked via ApiMocksConfig

    @Test
    void testSomething() {
        when(courseApi.getAllCourses()).thenReturn(Flux.just(someCourse));
        assertThat(myService.doThing()).isEqualTo(expected);
    }
}
```

Key rules:
- Use `TestApplication` (not main app class) to load test configs.
- All `ControllerApi` beans are mocked via shared `ApiMocksConfig` with `@MockBean`.
- Always mock LabraCore API calls — never send real HTTP in tests.
- Use `@Transactional` for automatic rollback.
- Stub reactive types with `Flux.just(...)` / `Mono.just(...)`.

### Controller Tests (MockMvc)
```java
@WebMvcTest(MyController.class)
@Import({ApiMocksConfig.class})
public class MyControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private MyService myService;

    @Test
    void getPage() throws Exception {
        when(myService.getRequired(1L)).thenReturn(someEntity);
        mockMvc.perform(get("/my-entity/1"))
            .andExpect(status().isOk())
            .andExpect(model().attributeExists("entity"));
    }
}
```

## LabraDoor Integration Pattern

When a Labrador app needs data from LabraCore:

```java
@Service
@AllArgsConstructor
public class CourseService {
    private final CourseControllerApi courseApi;

    public List<CourseSummaryDTO> getAllCourses() {
        return courseApi.getAllCourses().collectList().block();
    }
}
```

Application bootstrap:
```java
@EnableLibrador
@SpringBootApplication
@Import(LabracoreApiConfig.class)
public class MyApplication { ... }
```

Config (application.yml):
see ./src/main/resources/application.yml or ./src/main/resouces/application.template.yaml


LibradorConfig:
```java
@Configuration
public class LibradorConfig extends LibradorConfigAdapter {
    @Override
    protected void configure(IdMapperBuilder builder) {}
}
```

## Code Review Checklist

1. Controllers only depend on services (not repos, caches, or APIs directly)
3. No circular service dependencies
5. DTOs contain no business logic
6. No expensive Thymeleaf bean calls
7. `th:unless` used instead of `th:if="${not ...}"`
10. Liquibase migrations are additive (no destructive changes to existing changesets)

## Debugging Tips

- **LabraDoor connection errors**: Check `application.yml` — correct `labrador.core.url`, apiKey, apiSecret. Ensure LabraCore runs on port 8082. If you can't get core running just stop and delegate to user, Henry should already have it running in background.
- **Flux/Mono NPE**: Null-check `.block()` results. Use `Mono.justOrEmpty()` in mocks.
- **H2 vs PostgreSQL**: Test with both if using native queries. H2 doesn't support all PG features.

## COMMIT PROCESS
DON'T CO-SIGN COMMITS AND don't write descriptions in commits. Keep it only to the message and follow conventional commits.
