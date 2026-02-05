# Finy-Ops Examples - Kafka Integration for Spring Boot

This folder contains example code for integrating Kafka with Spring Boot 2.7.8 applications.

## Files Overview

### 1. KafkaConfig.java
Spring configuration class that defines Kafka topics with their settings:
- `jenkins-builds`: For Jenkins build events
- `deployment-events`: For deployment notifications
- `app-logs`: For application logging
- `dlq-errors`: Dead letter queue for failed messages

### 2. KafkaProducerService.java
Service class for sending messages to Kafka topics:
- Asynchronous message sending with callbacks
- Synchronous message sending (blocking)
- Custom topic support
- Error handling and logging

### 3. KafkaConsumerService.java
Service class for consuming messages from Kafka topics:
- Simple consumer with auto-acknowledgement
- Consumer with metadata (partition, offset, timestamp)
- Multi-topic consumer
- Example for manual acknowledgement (commented)
- Example for batch processing (commented)

### 4. KafkaTestController.java
REST API controller for testing Kafka integration:
- `POST /api/kafka/send`: Send simple test messages
- `POST /api/kafka/build-event`: Send structured build events
- `GET /api/kafka/health`: Health check endpoint

## Usage in Your Spring Boot Project

### Step 1: Add Dependencies to pom.xml

```xml
<dependencies>
    <!-- Spring Kafka -->
    <dependency>
        <groupId>org.springframework.kafka</groupId>
        <artifactId>spring-kafka</artifactId>
    </dependency>
    
    <!-- Spring Boot Actuator (for health checks) -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    
    <!-- Spring Web (if not already included) -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
</dependencies>
```

### Step 2: Configure application.yml

Copy settings from `application.yml.example` in the root folder.

Key configurations:
```yaml
spring:
  kafka:
    bootstrap-servers: localhost:9092  # or kafka:9092 in Docker
    consumer:
      group-id: ${spring.application.name}-group
    producer:
      acks: all
      retries: 3
```

### Step 3: Copy Example Files

Copy the Java files to your project:

```bash
# Copy to your project source directory
cp examples/*.java your-project/src/main/java/com/yourcompany/yourapp/kafka/
```

Update package names to match your project structure.

### Step 4: Test the Integration

1. **Start the platform:**
   ```bash
   ./start.ps1  # Windows
   # or
   ./start.sh   # Linux/Mac
   ```

2. **Run your Spring Boot application:**
   ```bash
   mvn spring-boot:run
   # or
   gradle bootRun
   ```

3. **Send test message via REST API:**
   ```bash
   # Simple message
   curl -X POST "http://localhost:8080/api/kafka/send?message=HelloKafka"
   
   # Build event
   curl -X POST http://localhost:8080/api/kafka/build-event \
     -H "Content-Type: application/json" \
     -d '{"status":"success","branch":"main","buildNumber":123}'
   ```

4. **Check logs to see consumer output:**
   ```
   INFO  c.e.f.k.KafkaConsumerService : Received message: HelloKafka
   ```

5. **View messages in Kafka UI:**
   Open http://localhost:8090 and browse topics.

## Advanced Usage

### Manual Acknowledgement

Uncomment the `consumeWithManualAck` method in `KafkaConsumerService.java` and configure:

```yaml
spring:
  kafka:
    listener:
      ack-mode: MANUAL
```

### Batch Processing

Uncomment the `consumeBatch` method and configure:

```yaml
spring:
  kafka:
    listener:
      type: BATCH
    consumer:
      max-poll-records: 100
```

### Error Handling with DLQ

Add a consumer exception handler:

```java
@Bean
public DefaultErrorHandler errorHandler() {
    DeadLetterPublishingRecoverer recoverer = new DeadLetterPublishingRecoverer(
        kafkaTemplate(),
        (record, ex) -> new TopicPartition("dlq-errors", -1)
    );
    
    return new DefaultErrorHandler(recoverer, 
        new FixedBackOff(1000L, 3L));
}
```

### JSON Serialization

For complex objects, use JSON serializer/deserializer:

```yaml
spring:
  kafka:
    producer:
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
    consumer:
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      properties:
        spring.json.trusted.packages: "com.yourcompany.yourapp.*"
```

## Testing

### Unit Tests

```java
@SpringBootTest
@EmbeddedKafka(partitions = 1, topics = {"test-topic"})
class KafkaIntegrationTest {
    
    @Autowired
    private KafkaProducerService producer;
    
    @Test
    void testSendMessage() {
        producer.sendMessage("key1", "test message");
        // Verify message is sent
    }
}
```

### Integration Tests

Use Testcontainers for full Kafka integration tests:

```xml
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>kafka</artifactId>
    <scope>test</scope>
</dependency>
```

## Troubleshooting

### Connection Refused
- Ensure Kafka is running: `podman ps | grep kafka`
- Check bootstrap-servers configuration
- Verify network connectivity

### Messages Not Consumed
- Check consumer group ID
- Verify topic exists: `podman exec kafka kafka-topics.sh --list --bootstrap-server localhost:9092`
- Check consumer logs for errors

### Serialization Errors
- Ensure serializer/deserializer match between producer and consumer
- For JSON, configure trusted packages

## Best Practices

1. **Use meaningful topic names**: Follow naming conventions like `domain.entity.action`
2. **Set appropriate retention**: Balance between storage and data availability
3. **Use partitioning wisely**: More partitions = more parallelism
4. **Monitor consumer lag**: Use Kafka UI or monitoring tools
5. **Handle errors gracefully**: Implement dead letter queues
6. **Use transactions for critical operations**: Enable idempotence
7. **Test with realistic data volumes**: Performance varies with load

## Additional Resources

- [Spring Kafka Documentation](https://docs.spring.io/spring-kafka/reference/html/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Context7 Kafka Guide](https://context7.com/apache/kafka/llms.txt)

## Support

For issues or questions:
1. Check the main README.md
2. Review Kafka logs: `podman logs kafka`
3. Check Spring Boot logs
4. Visit Kafka UI: http://localhost:8090
