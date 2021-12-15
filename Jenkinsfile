pipeline {

  options {
    ansiColor('xterm')
  }

  agent {
    kubernetes {
      yamlFile 'builder.yaml'
    }
  }

  stages {
    stage('Build application images with Kaniko and push them into DockerHub public repository') {
      parallel {
        stage('Kaniko - build & push Producer app image') {
          steps {
            container('kaniko') {
              script {
                sh '''
                /kaniko/executor --dockerfile `pwd`/producer/Dockerfile \
                                 --context `pwd`/producer \
                                --destination=alexfersh/producer:${BUILD_NUMBER}
                '''
              }
            }
          }
        }
        stage('Kaniko - build & push Consumer app image') {
          steps {
            container('kaniko') {
              script {
                sh '''
                /kaniko/executor --dockerfile `pwd`/consumer/Dockerfile \
                                 --context `pwd`/consumer \
                                 --destination=alexfersh/consumer:${BUILD_NUMBER}
                '''
              }
            }
          }
        }
      }
    }
    stage('Deploy App to Kubernetes') {     
      steps {
        container('kubectl') {
          withCredentials([file(credentialsId: 'mykubeconfig', variable: 'KUBECONFIG')]) {
            sh 'sed -i "s/<TAG>/${BUILD_NUMBER}/" project.yaml'
            sh 'kubectl apply -f project.yaml'
          }
        }
      }
    }
  }

}