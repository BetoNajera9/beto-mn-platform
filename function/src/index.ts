import type { AWS } from '@serverless/typescript'

export const sendEmail: NonNullable<AWS['functions']>['sendEmail'] = {
  handler: 'src/handler.main',
  timeout: 90,

  events: [
    {
      http: {
        path: '/send-email',
        method: 'post',
        cors: true,
      },
    },
  ],

  iamRoleStatements: [
    {
      Effect: 'Allow',
      Action: ['ses:SendEmail', 'ses:SendRawEmail'],
      Resource: '*',
    },
  ],
}
