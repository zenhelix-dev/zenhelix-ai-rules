---
name: tdd-workflow-java
description: "Java implementation patterns for TDD workflow. Use with `tdd-workflow` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: opus
---

# TDD Workflow — Java

Prerequisites: load `tdd-workflow` skill for foundational concepts.

## Test Naming Conventions

Java (method naming):

```java
void shouldReturnUser_whenFoundById()
void shouldThrowNotFoundException_whenUserDoesNotExist()
void shouldCreateUser_withHashedPassword()
```

## Mock Patterns with Mockito

### Basic Mocking

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    UserRepository userRepository;

    @InjectMocks
    UserService userService;

    @Test
    void shouldReturnUser_whenFoundById() {
        var user = new User(1L, "Alice", "alice@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        var result = userService.findById(1L);

        assertThat(result).isEqualTo(user);
        verify(userRepository, times(1)).findById(1L);
    }
}
```

### Argument Captor

```java
@Captor
ArgumentCaptor<User> userCaptor;

@Test
void shouldSaveUserWithHashedPassword() {
    userService.create(new CreateUserRequest("Bob", "bob@test.com"));

    verify(userRepository).save(userCaptor.capture());
    assertThat(userCaptor.getValue().getName()).isEqualTo("Bob");
    assertThat(userCaptor.getValue().getPasswordHash()).isNotNull();
}
```

### BDD Style

```java
import static org.mockito.BDDMockito.*;

@Test
void shouldReturnUser_whenFoundById() {
    given(userRepository.findById(1L)).willReturn(Optional.of(user));

    var result = userService.findById(1L);

    then(userRepository).should().findById(1L);
    assertThat(result).isEqualTo(user);
}
```

## Test Fixtures

### Java Record Builders

```java
class TestUsers {
    static User alice() {
        return new User(1L, "Alice", "alice@example.com");
    }

    static CreateUserRequest createRequest() {
        return new CreateUserRequest("NewUser", "newuser@example.com", "SecureP@ss123");
    }
}
```

<!-- TODO: Add Java TestContainers integration test example -->

<!-- TODO: Add Java Spring Test Patterns example -->
