---
root: false
targets: ["claudecode"]
description: "Java testing: JUnit 5, Mockito, AssertJ, Spring Boot test slices, Testcontainers, and coverage"
globs: ["*.java"]
---

# Java Testing

## Framework Stack

- **JUnit 5** — test framework
- **Mockito** — mocking
- **AssertJ** — fluent assertions
- **MockMvc** — controller testing
- **Testcontainers** — integration testing with real databases
- **JaCoCo** — coverage (80%+ required)

## Test Naming

Use the pattern `methodName_scenario_expectedResult`:

```java
class UserServiceTest {

    @Test
    void createUser_validInput_returnsCreatedUser() { }

    @Test
    void createUser_duplicateEmail_throwsConflictException() { }

    @Test
    void findUser_nonExistentId_returnsEmpty() { }
}
```

## Test Organization

Use `@Nested` for logical grouping:

```java
class OrderServiceTest {

    @Nested
    class CreateOrder {

        @Test
        void validItems_createsOrder() { }

        @Test
        void emptyItems_throwsValidationException() { }
    }

    @Nested
    class CancelOrder {

        @Test
        void pendingOrder_cancelsSuccessfully() { }

        @Test
        void shippedOrder_throwsIllegalStateException() { }
    }
}
```

## Mockito

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private EmailService emailService;

    @InjectMocks
    private UserService userService;

    @Test
    void createUser_validInput_savesAndSendsEmail() {
        // given
        var request = new CreateUserRequest("Alice", "alice@example.com");
        var savedUser = new User(1L, "Alice", "alice@example.com");
        when(userRepository.save(any(User.class))).thenReturn(savedUser);

        // when
        var result = userService.createUser(request);

        // then
        assertThat(result.getId()).isEqualTo(1L);
        verify(emailService).sendWelcomeEmail("alice@example.com");
        verify(userRepository).save(argThat(user ->
            user.getName().equals("Alice") &&
            user.getEmail().equals("alice@example.com")
        ));
    }
}
```

### Argument Captors

```java
@Test
void createUser_normalizesEmail() {
    var captor = ArgumentCaptor.forClass(User.class);
    when(userRepository.save(captor.capture())).thenReturn(new User());

    userService.createUser(new CreateUserRequest("Alice", "ALICE@Example.COM"));

    assertThat(captor.getValue().getEmail()).isEqualTo("alice@example.com");
}
```

## AssertJ

Use fluent assertions for readability:

```java
// Basic
assertThat(user.getName()).isEqualTo("Alice");
assertThat(users).hasSize(3);
assertThat(result).isNotNull().isInstanceOf(SuccessResponse.class);

// Collections
assertThat(users)
    .filteredOn(User::isActive)
    .extracting(User::getName)
    .containsExactly("Alice", "Bob");

// Exceptions
assertThatThrownBy(() -> service.process(invalidInput))
    .isInstanceOf(ValidationException.class)
    .hasMessageContaining("invalid")
    .hasFieldOrPropertyWithValue("code", "VALIDATION_ERROR");

// Soft assertions — report all failures at once
SoftAssertions.assertSoftly(softly -> {
    softly.assertThat(response.getStatus()).isEqualTo(200);
    softly.assertThat(response.getBody()).isNotNull();
    softly.assertThat(response.getHeaders()).containsKey("Content-Type");
});
```

## Parameterized Tests

```java
@ParameterizedTest
@CsvSource({
    "alice@example.com, true",
    "invalid-email, false",
    "'', false",
    "a@b, false"
})
void isValidEmail_variousInputs_returnsExpected(String email, boolean expected) {
    assertThat(EmailValidator.isValid(email)).isEqualTo(expected);
}

@ParameterizedTest
@EnumSource(value = OrderStatus.class, names = {"PENDING", "CONFIRMED"})
void cancelOrder_cancellableStatuses_succeeds(OrderStatus status) {
    var order = TestData.orderWithStatus(status);
    assertThatNoException().isThrownBy(() -> service.cancel(order));
}

@ParameterizedTest
@MethodSource("invalidRequests")
void createUser_invalidRequest_throwsValidation(CreateUserRequest request, String expectedField) {
    assertThatThrownBy(() -> service.createUser(request))
        .hasFieldOrPropertyWithValue("field", expectedField);
}

static Stream<Arguments> invalidRequests() {
    return Stream.of(
        Arguments.of(new CreateUserRequest("", "a@b.com"), "name"),
        Arguments.of(new CreateUserRequest("Alice", ""), "email")
    );
}
```

## Spring Boot Test Slices

Prefer sliced tests over `@SpringBootTest`:

### Controller Tests

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    void getUser_existingId_returnsUser() throws Exception {
        when(userService.findById(1L)).thenReturn(Optional.of(TestData.user()));

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Alice"))
            .andExpect(jsonPath("$.email").value("alice@example.com"));
    }

    @Test
    void getUser_nonExistentId_returns404() throws Exception {
        when(userService.findById(999L)).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/users/999"))
            .andExpect(status().isNotFound());
    }
}
```

### Repository Tests

```java
@DataJpaTest
class UserRepositoryTest {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void findByEmail_existingEmail_returnsUser() {
        entityManager.persistAndFlush(new User("Alice", "alice@example.com"));

        var result = userRepository.findByEmail("alice@example.com");

        assertThat(result).isPresent();
        assertThat(result.get().getName()).isEqualTo("Alice");
    }
}
```

## Testcontainers

Use for integration tests with real infrastructure:

```java
@SpringBootTest
@Testcontainers
class UserIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16")
        .withDatabaseName("testdb");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserService userService;

    @Test
    void createAndFindUser_fullFlow() {
        var created = userService.create(new CreateUserRequest("Alice", "alice@test.com"));
        var found = userService.findById(created.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("Alice");
    }
}
```

## Test Data

Create test data builders or use static factory methods:

```java
public final class TestData {

    private TestData() {}

    public static User user() {
        return new User(1L, "Test User", "test@example.com", Role.USER, true);
    }

    public static User adminUser() {
        return new User(2L, "Admin", "admin@example.com", Role.ADMIN, true);
    }

    public static CreateUserRequest createUserRequest() {
        return new CreateUserRequest("New User", "new@example.com");
    }
}
```

## Coverage

Run JaCoCo and enforce 80% minimum:

```xml
<!-- Maven -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <configuration>
        <rules>
            <rule>
                <limits>
                    <limit>
                        <counter>LINE</counter>
                        <value>COVEREDRATIO</value>
                        <minimum>0.80</minimum>
                    </limit>
                </limits>
            </rule>
        </rules>
    </configuration>
</plugin>
```

```bash
mvn verify          # Maven
./gradlew test jacocoTestReport   # Gradle
```
