node {
    stage 'Checkout'
    git url: 'git@bitbucket.org:example/repo.git', branch: 'app-cluster'
    def tfHome = tool name: 'terraform', type: 'com.cloudbees.jenkins.plugins.customtools.CustomTool'
    env.PATH = "${tfHome}:${env.PATH}"
    wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
        stage name: 'Plan', concurrency: 1
        dir ('terraform-templates/web-cluster-1') {
            if (fileExists("status")) {
                sh "rm status"
            }
            sh "terraform get"
            sh "terraform env select ${env.ENVIRONMENT}"
            sh "set +e; terraform plan -out=plan.out -detailed-exitcode; echo \$? > status"
            def exitCode = readFile('status').trim()
            def apply = false
            def version = sh (
              script: "terraform show | grep family | tr -d 'family ='",
              returnStdout: true
            )
            echo "Terraform Plan Exit Code: ${exitCode}"
            if (exitCode == "0") {
                currentBuild.result = 'SUCCESS'
            }
            if (exitCode == "1") {
                slackSend color: '#0080ff', message: "Plan Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
                currentBuild.result = 'FAILURE'
            }
            if (exitCode == "2") {
                stash name: "plan", includes: "plan.out"
                slackSend color: 'warning', message: "Plan Awaiting Approval: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
                try {
                    input message: 'Apply Plan?', ok: 'Apply'
                    apply = true
                } catch (err) {
                    slackSend color: 'warning', message: "Plan Discarded: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
                    apply = false
                    currentBuild.result = 'UNSTABLE'
                }
            }
            if (apply) {
                stage name: 'Apply', concurrency: 1
                unstash 'plan'
                if (fileExists("status.apply")) {
                    sh "rm status.apply"
                }
                sh 'set +e; terraform apply plan.out; echo \$? &> status.apply'
                def applyExitCode = readFile('status.apply').trim()
                if (applyExitCode == "0") {
                    slackSend color: 'good', message: "Changes Applied ${env.JOB_NAME} | ${version} | ${env.BUILD_NUMBER}"
                    sh "git add terraform.tfstate.d -A && git commit -m \"New Deployment\" && git push origin app-cluster"
                } else {
                    slackSend color: 'danger', message: "Apply Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
                    currentBuild.result = 'FAILURE'
                }
            }
        }
    }
}


