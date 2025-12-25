import type { AWS } from '@serverless/typescript'

import { sendEmail } from './src'

const serverlessConfig: AWS = {
  service: 'beto-mn-platform-function',
  frameworkVersion: '4',

  provider: {
    name: 'aws',
    runtime: 'nodejs24.x',
    environment: {
      AWS_NODEJS_CONNECTION_REUSE_ENABLED: '1',
      NODE_OPTIONS: '--enable-source-maps',
    },
    apiGateway: {
      restApiId: '0iz3178srb',
      restApiRootResourceId: '0i1unpz121',
    },
  },

  functions: {
    sendEmail,
  },
}

module.exports = serverlessConfig
