# GitBull Reference

GitBull is GitLab management software that automates repository creation for student groups and provides detailed statistics on GitLab projects.

## Domain Concepts

- **GitLab Project** — a Git repository on `gitlab.ewi.tudelft.nl`, typically one per student group per course.
- **Group Repository** — auto-created repo for a student group, with correct permissions.
- **Project Statistics** — commit counts, contributor stats, activity metrics per project.
- **GitLab API** — GitBull interacts with GitLab's REST API to create repos, manage access, fetch stats.

## Key Technical Details

### GitLab API Integration
GitBull communicates with the TU Delft GitLab instance via its REST API:
- Create projects/groups
- Manage member access (add/remove students and TAs)
- Fetch commit history, merge request stats, CI pipeline results

Uses `RestClient` or `WebClient` for HTTP calls to GitLab API.


### LabraCore Integration
GitBull fetches from LabraCore:
- Student groups (to know which repos to create)
- Edition/course info (to organize repos under correct GitLab groups)
- Person details (to set GitLab permissions)


## Architecture Notes

### Service Pattern
```java
@Service
@AllArgsConstructor
public class RepositoryService {
    private final GitLabApiService gitLabApi;
    private final StudentGroupControllerApi groupApi;
    private final ProjectRepository projectRepository;

    public void createRepositoriesForEdition(Long editionId) {
        var groups = groupApi.getGroupsByEdition(editionId).collectList().block();
        for (var group : groups) {
            var project = gitLabApi.createProject(buildCreateDTO(group));
            projectRepository.save(mapToEntity(project));
        }
    }
}
```

### Testing GitLab API Calls
- Mock the GitLab API service in tests — never call real GitLab
- Test retry behavior with `@SpringBootTest` + deliberate failure injection
- Verify idempotency: creating repos that already exist should not fail

```java
@Test
void createProject_retries_on_failure() {
    when(gitLabApi.createProject(any()))
        .thenThrow(new GitLabApiException("503"))
        .thenReturn(successResponse);

    var result = repositoryService.createProject(dto);
    assertThat(result).isNotNull();
    verify(gitLabApi, times(2)).createProject(any());
}
```

## Common Tasks

### Adding a New GitLab Operation
See `GitlabApiService`

### Modifying Repo Creation Logic
1. Update `RepositoryService.createRepositoriesForEdition()` or equivalent
2. Ensure correct GitLab permissions are set (students = Developer, TAs = Maintainer)
3. Handle partial failures (some repos created, some failed)
4. Test with mocked LabraCore groups + mocked GitLab API

### Adding Statistics
1. Fetch from GitLab API (commits, MRs, pipelines)
2. Store aggregated stats in local DB if needed for performance
3. Display via controller + Thymeleaf
4. Consider caching for expensive GitLab API calls

