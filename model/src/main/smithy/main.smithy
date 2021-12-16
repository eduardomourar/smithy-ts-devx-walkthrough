$version: "1.0"

namespace software.amazon.smithy.demo

use aws.api#service
use aws.api#controlPlane
use aws.api#dataPlane
use aws.auth#sigv4
use aws.protocols#restJson1
use aws.apigateway#integration
use aws.cloudformation#cfnResource
use aws.cloudformation#cfnExcludeProperty
use aws.cloudformation#cfnMutability
use smithy.framework#ValidationException

/// The date and time when the resource was created.
string CreatedAt

/// The date and time when the resource was updated.
string UpdatedAt

@error("client")
structure ClientError {
    /// Human readable error message
    @required
    message: String,

    /// Classification of the error type
    @required
    code: String
}

/// Example Compute
@restJson1()
@cors()
@httpApiKeyAuth(scheme: "Key", name: "Authorization", in: "header")
@paginated(inputToken: "nextToken", outputToken: "nextToken",
           pageSize: "pageSize")
@title("compute")
service Compute {
  version: "2021-11-16",
  resources: [Function, FunctionExecution],
}

/// A universal identifier of Example resources.
@pattern("^example:[a-zA-Z0-9_-]+:[a-zA-Z0-9_-]+:[a-zA-Z0-9_-]+:[a-zA-Z0-9_-]+[^.]+$")
string ExampleResourceIdentifier

@cfnResource(name: "Function")
resource Function {
  identifiers: { functionId: FunctionId },
  create: CreateFunction,
  read: ReadFunction,
  update: UpdateFunction,
  delete: DeleteFunction,
  list: ListFunctions,
}

/// The identifier for a given function.
@pattern("^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$")
string FunctionId

/// Create a new function.
@http(uri: "/functions", method: "POST")
@controlPlane
operation CreateFunction {
  input: CreateFunctionInput,
  output: FunctionOutput,
  errors: [ValidationException, ClientError]
}

structure CreateFunctionInput {
  @required
  name: String,

  code: String,

  @cfnMutability("write")
  package: String,

  @jsonName("environment_variables")
  environmentVariables: EnvironmentVariables,

  @internal
  @cfnExcludeProperty
  @jsonName("example_layer")
  exampleLayer: Boolean
}

/// Retrieve an existing function.
@readonly
@http(uri: "/functions/{functionId}", method: "GET")
@controlPlane
operation ReadFunction {
  input: ReadFunctionInput,
  output: FunctionOutput,
  errors: [ValidationException, ClientError]
}

structure ReadFunctionInput {
  @required
  @httpLabel
  functionId: FunctionId
}

/// Update an existing function.
@idempotent
@http(uri: "/functions/{functionId}", method: "POST")
@controlPlane
operation UpdateFunction {
  input: UpdateFunctionInput,
  output: FunctionOutput,
  errors: [ValidationException, ClientError]
}

structure UpdateFunctionInput {
  @required
  @httpLabel
  functionId: FunctionId,

  @required
  name: String,

  code: String,

  @sensitive
  package: String,

  @jsonName("environment_variables")
  environmentVariables: EnvironmentVariables,

  @jsonName("example_layer")
  @internal
  exampleLayer: Boolean,
}

/// Delete an existing function.
@idempotent
@http(uri: "/functions/{functionId}", method: "DELETE")
@controlPlane
operation DeleteFunction {
  input: DeleteFunctionInput,
  errors: [ValidationException, ClientError]
}

structure DeleteFunctionInput {
  @required
  @httpLabel
  functionId: FunctionId
}

/// Retrieve a list containing every function.
@readonly
@http(uri: "/functions", method: "GET")
@controlPlane
operation ListFunctions {
  output: ListFunctionsOutput,
  errors: [ValidationException, ClientError]
}

list FunctionItems {
    member: FunctionOutput
}

structure ListFunctionsOutput {

  resources: FunctionItems,

  @jsonName("next_page_token")
  nextPageToken: String,
}

structure FunctionOutput {
  @required
  id: FunctionId,

  @required
  name: String,

  code: String,

  @sensitive
  package: String,

  @jsonName("environment_variables")
  environmentVariables: EnvironmentVariables,

  @jsonName("example_layer")
  @internal
  exampleLayer: Boolean,

  @jsonName("log_group_id")
  logGroupId: String,

  @jsonName("created_at")
  createdAt: CreatedAt,

  @jsonName("updated_at")
  updatedAt: UpdatedAt
}

structure EnvironmentVariables {}

resource FunctionExecution {
  identifiers: { functionId: FunctionId , executionId: FunctionExecutionId },
  create: ExecuteFunction,
  read: ReadFunctionExecution,
  list: ListFunctionExecutions
}

/// The identifier for a given function execution.
string FunctionExecutionId

/// Execute an existing function.
@idempotent
@http(uri: "/functions/{functionId}/executions", method: "POST")
@dataPlane
operation ExecuteFunction {
  input: ExecuteFunctionInput,
  output: FunctionExecutionOutput,
  errors: [ValidationException, ClientError]
}

structure ExecuteFunctionInput {
  @required
  @httpLabel
  functionId: FunctionId,

  @required
  id: FunctionExecutionId,

  @required
  function: FunctionId,

  name: String,

  @jsonName("request_payload")
  requestPayload: RequestPayload,
}

string RequestPayload

/// Read an existing function execution.
@readonly
@http(uri: "/functions/{functionId}/executions/{executionId}", method: "GET")
@dataPlane
operation ReadFunctionExecution {
  input: ReadFunctionExecutionInput,
  output: FunctionExecutionOutput,
  errors: [ValidationException, ClientError]
}

structure ReadFunctionExecutionInput {
  @required
  @httpLabel
  functionId: FunctionId,

  @required
  @httpLabel
  executionId: FunctionExecutionId
}

/// Retrieve a list containing every function execution.
@readonly
@http(uri: "/functions/{functionId}/executions", method: "GET")
@dataPlane
operation ListFunctionExecutions {
  input: ListFunctionExecutionsInput,
  output: ListFunctionExecutionsOutput,
  errors: [ValidationException, ClientError]
}

structure ListFunctionExecutionsInput {
  @required
  @httpLabel
  functionId: FunctionId,
}

list FunctionExecutionItems {
    member: FunctionExecutionOutput
}

structure ListFunctionExecutionsOutput {

  resources: FunctionExecutionItems,

  @jsonName("next_page_token")
  nextPageToken: String
}

structure FunctionExecutionOutput {
  @required
  sri: ExampleResourceIdentifier,

  @required
  id: FunctionExecutionId,

  @required
  function: FunctionId,

  name: String,

  @jsonName("request_payload")
  requestPayload: RequestPayload,

  @jsonName("response_payload")
  responsePayload: ResponsePayload,

  status: String,

  @jsonName("log_group_name")
  logGroupName: String,

  @jsonName("created_at")
  createdAt: CreatedAt,

  @jsonName("updated_at")
  updatedAt: UpdatedAt
}

structure ResponsePayload {}


@title("A magical string manipulation service")

// Cross-origin resource sharing allows resources to be requested from external domains.
// Cors should be enabled for externally facing services and disabled for internally facing services.
// Enabling cors will modify the OpenAPI spec used to define your API Gateway endpoint.
// Uncomment the line below to enable cross-origin resource sharing
// @cors()

@sigv4(name: "execute-api")
@restJson1
service StringWizard {
    version: "2018-05-10",
    operations: [Echo, Length],
}

/// Echo operation that receives input from body.
@http(code: 200, method: "POST", uri: "/echo",)
operation Echo {
    input: EchoInput,
    output: EchoOutput,
    errors: [ValidationException, PalindromeException],
}

/// Length operation that receives input from path.
@readonly
@http(code: 200, method: "GET", uri: "/length/{string}",)
operation Length {
    input: LengthInput,
    output: LengthOutput,
    errors: [ValidationException, PalindromeException],
}

structure EchoInput {
    string: String,
}

structure EchoOutput {
    string: String,
}

structure LengthInput {
    @required
    @httpLabel
    string: String,
}

structure LengthOutput {
    length: Integer,
}

/// For some reason, this service does not like palindromes!
@httpError(400)
@error("client")
structure PalindromeException {
    message: String,
}
