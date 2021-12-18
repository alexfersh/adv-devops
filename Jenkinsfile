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
    stage('Kaniko - build & push Producer app image') {
      steps {
        container('kaniko') {
          script {
            sh '''
            /kaniko/executor --context `pwd`/producer \
                             --dockerfile `pwd`/producer/Dockerfile \
                             --destination=alexfersh/producer:${BUILD_NUMBER} \
                             --destination=alexfersh/producer:latest \
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
            /kaniko/executor --context `pwd`/consumer \
                             --dockerfile `pwd`/consumer/Dockerfile \
                             --destination=alexfersh/consumer:${BUILD_NUMBER} \
                             --destination=alexfersh/consumer:latest \
                             --cleanup
            '''
          }
        }
      }
    }
    stage('Deploy App to Kubernetes') {     
      steps {
        container('kubectl') {
          withCredentials([file(credentialsId: 'mykubeconfig', variable: 'KUBECONFIG')]) {
            //sh 'sed -i "s/<TAG>/${BUILD_NUMBER}/" project.yaml'
            sh 'sed -i "s/<TAG>/latest/" project.yaml'
            sh 'kubectl apply -f project.yaml'
          }
        }
      }
    }
  }

}