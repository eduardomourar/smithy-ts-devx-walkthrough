import { AnyPrincipal, Effect, PolicyDocument, PolicyStatement, ServicePrincipal } from "@aws-cdk/aws-iam";
import { NodejsFunction } from "@aws-cdk/aws-lambda-nodejs";
import { LogGroup } from "@aws-cdk/aws-logs";
import { readFileSync } from "fs";
import * as path from "path";
import {
  AccessLogFormat,
  ApiDefinition,
  LogGroupLogDestination,
  MethodLoggingLevel,
  SpecRestApi,
} from "@aws-cdk/aws-apigateway";
import { Construct, Stack, StackProps } from "@aws-cdk/core";
import { StringWizardServiceOperations } from "@smithy-demo/string-wizard-service-ssdk";
import {Runtime} from "@aws-cdk/aws-lambda";

export class CdkStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const logGroup = new LogGroup(this, "ApiLogs");

    const entry_points: { [op in StringWizardServiceOperations]: string } = {
      Echo: "echo_handler",
      Length: "length_handler",
    };

    const functions = (Object.keys(entry_points) as StringWizardServiceOperations[]).reduce(
      (acc, operation) => ({
        ...acc,
        [operation]: new NodejsFunction(this, operation + "Function", {
          entry: path.join(__dirname, `../src/${entry_points[operation]}.ts`),
          handler: "lambdaHandler",
          depsLockFilePath: path.join(__dirname, "../../yarn.lock"),
          runtime: Runtime.NODEJS_14_X,
          bundling: {
            minify: true,
            tsconfig: path.join(__dirname, "../tsconfig.json"),
            forceDockerBundling: true,
            // Re2 is used by the SSDK common library to do pattern validation, and uses
            // native code, so it's included here.
            nodeModules: ["re2"],
          },
        }),
      }),
      {}
    ) as { [op in StringWizardServiceOperations]: NodejsFunction };

    const api = new SpecRestApi(this, "StringWizardApi", {
      apiDefinition: ApiDefinition.fromInline(this.getOpenApiDef(functions)),
      deploy: true,
      deployOptions: {
        accessLogDestination: new LogGroupLogDestination(logGroup),
        accessLogFormat: AccessLogFormat.jsonWithStandardFields(),
        loggingLevel: MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
      },
      policy: new PolicyDocument({
        statements: [
          new PolicyStatement({
            effect: Effect.ALLOW,
            principals: [new AnyPrincipal()],
            actions: ["execute-api:Invoke"],
            resources: ["execute-api:/*/*/*"],
          }),
        ],
      }),
    });

    for (const [k, v] of Object.entries(functions)) {
      v.addPermission(`${k}Permission`, {
        principal: new ServicePrincipal("apigateway.amazonaws.com"),
        sourceArn: `arn:${this.partition}:execute-api:${this.region}:${this.account}:${api.restApiId}/*/*/*`,
      });
    }
  }

  private getOpenApiDef(functions: { [op in StringWizardServiceOperations]?: NodejsFunction }) {
    const openapi = JSON.parse(
      readFileSync(
        path.join(__dirname, "../codegen/build/smithyprojections/codegen/apigateway/openapi/StringWizard.openapi.json"),
        "utf8"
      )
    );
    for (const path in openapi.paths) {
      for (const operation in openapi.paths[path]) {
        const op = openapi.paths[path][operation];
        const integration = op["x-amazon-apigateway-integration"];
        // Don't try to mess with mock integrations
        if (integration !== null && integration !== undefined && integration["type"] === "mock") {
          continue;
        }
        const functionArn = functions[op.operationId as StringWizardServiceOperations]?.functionArn;
        if (functionArn === null || functionArn === undefined) {
          throw new Error("no function for " + op.operationId);
        }
        op[
          "x-amazon-apigateway-integration"
        ].uri = `arn:${this.partition}:apigateway:${this.region}:lambda:path/2015-03-31/functions/${functionArn}/invocations`;
      }
    }
    return openapi;
  }
}
