mock_provider "aws" {
  # aws_iam_policy_document.json must be a parseable JSON object; the default
  # mock value is an empty string, which fails validation on aws_iam_role.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name             = "test-service"
  task_cpu         = 256
  task_memory      = 512
  vpc_id           = "vpc-12345678"
  subnets          = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
  ecs_cluster_name = "test-cluster"

  container_definitions = [
    {
      name  = "app"
      image = "nginx:latest"
      port_mappings = [
        { containerPort = 80 }
      ]
    }
  ]

  scaling = {
    min_capacity = 1
    max_capacity = 10
  }
}

run "predefined_alb_wires_resource_label" {
  command = plan

  variables {
    scaling_target = {
      alb = {
        predefined_metric_type = "ALBRequestCountPerTarget"
        resource_label         = "app/my-alb/50dc6c495c0c9188/targetgroup/my-tg/6d482bd40d5df576"
        target_value           = 1000
      }
    }
  }

  assert {
    condition     = aws_appautoscaling_policy.target["alb"].target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ALBRequestCountPerTarget"
    error_message = "Expected predefined_metric_type = ALBRequestCountPerTarget, got ${aws_appautoscaling_policy.target["alb"].target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type}"
  }

  assert {
    condition     = aws_appautoscaling_policy.target["alb"].target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].resource_label == "app/my-alb/50dc6c495c0c9188/targetgroup/my-tg/6d482bd40d5df576"
    error_message = "resource_label was not passed through to predefined_metric_specification"
  }

  assert {
    condition     = length(aws_appautoscaling_policy.target["alb"].target_tracking_scaling_policy_configuration[0].customized_metric_specification) == 0
    error_message = "Expected no customized_metric_specification block when predefined_metric_type is set"
  }
}

run "customized_sqs_wires_metric_and_dimensions" {
  command = plan

  variables {
    scaling_target = {
      queue = {
        customized_metric_specification = {
          metric_name = "ApproximateNumberOfMessagesVisible"
          namespace   = "AWS/SQS"
          statistic   = "Average"
          dimensions = [
            { name = "QueueName", value = "my-worker-queue" }
          ]
        }
        target_value = 100
      }
    }
  }

  assert {
    condition     = aws_appautoscaling_policy.target["queue"].target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].metric_name == "ApproximateNumberOfMessagesVisible"
    error_message = "Expected metric_name = ApproximateNumberOfMessagesVisible"
  }

  assert {
    condition     = aws_appautoscaling_policy.target["queue"].target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].namespace == "AWS/SQS"
    error_message = "Expected namespace = AWS/SQS"
  }

  assert {
    condition     = aws_appautoscaling_policy.target["queue"].target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].statistic == "Average"
    error_message = "Expected statistic = Average"
  }

  assert {
    condition     = length([for d in aws_appautoscaling_policy.target["queue"].target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].dimensions : d if d.name == "QueueName" && d.value == "my-worker-queue"]) == 1
    error_message = "Expected a dimension { name = QueueName, value = my-worker-queue } to be emitted"
  }

  assert {
    condition     = length(aws_appautoscaling_policy.target["queue"].target_tracking_scaling_policy_configuration[0].predefined_metric_specification) == 0
    error_message = "Expected no predefined_metric_specification block when customized_metric_specification is set"
  }
}

run "validation_rejects_both_specifications_set" {
  command = plan

  variables {
    scaling_target = {
      bad = {
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
        customized_metric_specification = {
          metric_name = "x"
          namespace   = "y"
          statistic   = "Average"
        }
        target_value = 50
      }
    }
  }

  expect_failures = [var.scaling_target]
}
