package com.example.tasks.controller;

import com.example.tasks.model.Task;
import com.example.tasks.repository.TaskRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaskControllerTest {

    @Mock
    private TaskRepository taskRepository;

    @InjectMocks
    private TaskController taskController;

    @Test
    void testGetTasks() {
        Task task1 = new Task(1L, "Learn CI/CD", "GitHub Actions Matrix Strategy", true);
        Task task2 = new Task(2L, "Gradle Caching", "Optimize build performance", false);
        when(taskRepository.findAll()).thenReturn(Arrays.asList(task1, task2));

        List<Task> result = taskController.getTasks();

        assertNotNull(result);
        assertEquals(2, result.size());
        assertEquals("Learn CI/CD", result.get(0).getTitle());
    }
}
