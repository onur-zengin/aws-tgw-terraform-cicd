data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# fixme - Use AWS Access Analyzer to update the following policy later for least-privilege rights. 

data "aws_iam_policy_document" "iam_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "iac_codebuild" {
  name               = "${var.resource_prefix}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "example" {
  role   = aws_iam_role.iac_codebuild.name
  policy = data.aws_iam_policy_document.iam_permissions.json
}

resource "aws_codecommit_repository" "repo" {
  repository_name = var.repository_name
  description     = "Private IaC Repo to be used as the Pipeline Trigger"
  default_branch  = var.default_branch
}


resource "aws_codebuild_project" "build_upon_git-tag" {
  for_each      = toset(var.environment_prefixes)
  name          = "${each.key}-${aws_codecommit_repository.repo.repository_name}-src"
  description   = "src_codebuild_project"
  build_timeout = "5"
  #service_role  = data.aws_iam_role.iac_codebuild.arn
  service_role = aws_iam_role.iac_codebuild.arn

  artifacts {
    type      = "S3"
    location  = aws_s3_bucket.repo_artifacts[each.key].bucket
    name      = "${each.key}-${aws_codecommit_repository.repo.repository_name}-src"
    packaging = "ZIP"
  }

  cache {
    type     = "S3"
    location = aws_s3_bucket.repo_artifacts[each.key].bucket
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type         = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.repo_artifacts[each.key].bucket}/build-log"
    }
  }

  source {
    type      = "CODECOMMIT"
    location  = aws_codecommit_repository.repo.clone_url_http
    buildspec = file("${path.cwd}/modules/global/cicd/buildspecs/tagged_source.yml")
  }

  source_version = var.default_branch

  tags = {
    Environment = each.value
  }
}


resource "aws_s3_bucket" "repo_artifacts" {
  for_each      = toset(var.environment_prefixes)
  bucket_prefix = "repo-artifacts-${each.key}"
  force_destroy = true // for demo purposes only
}

resource "aws_s3_bucket_versioning" "enabled" {
  for_each = tomap(aws_s3_bucket.repo_artifacts)
  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}


# CodeBuild as Target for git tag push
resource "aws_cloudwatch_event_rule" "trigger_build_on_tag_updates" {
  for_each    = toset(var.tag_prefix_list)
  name        = "trigger_codebuild_on_tag_update_${each.key}"
  description = "Trigger code build on ${each.key} tag update"

  event_pattern = <<EOF
{
  "source": [
    "aws.codecommit"
  ],
  "detail-type": [
    "CodeCommit Repository State Change"
  ],
  "resources": [
    "${aws_codecommit_repository.awsomerepo.arn}"
  ],
  "detail": {
    "event": [
      "referenceCreated",
      "referenceUpdated"
    ],
    "repositoryName": [
      "${aws_codecommit_repository.awsomerepo.repository_name}"
    ],
    "referenceType": [
      "tag"
    ],
    "referenceName": [
      { "prefix": "${each.key}" }
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "codebuild" {
  for_each  = toset(var.tag_prefix_list)
  rule      = aws_cloudwatch_event_rule.trigger_build_on_tag_updates[each.key].name
  target_id = "SendToCodeBuild"
  arn       = aws_codebuild_project.build_upon_tag_creation[each.key].arn
  role_arn  = data.aws_iam_role.cloudwatch_event_role.arn

  input_transformer {
    input_paths = {
      git_tag = "$.detail.referenceName"
    }
    input_template = "{ \"environmentVariablesOverride\": [ { \"name\": \"TAG\", \"value\": <git_tag> } ]}"
  }
}


