import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

export const main = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  try {
    console.log('Event:', JSON.stringify(event, null, 2));

    // Aquí irá tu lógica de negocio
    const body = JSON.parse(event.body || '{}');

    console.log('Parsed Body:', body);

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify({
        message: 'Email sent successfully',
        data: body,
      }),
    };
  } catch (error) {
    console.error('Error:', error);

    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify({
        message: 'Error sending email',
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
    };
  }
};