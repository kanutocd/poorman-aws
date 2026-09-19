const consumerFrontendDirectory = process.env.CONSUMER_FRONTEND_DIRECTORY?.trim();
const frontendHostname = process.env.FRONTEND_HOSTNAME?.trim();
const certificateArn = process.env.FRONTEND_CERTIFICATE_ARN?.trim();
const apiBaseUrl = process.env.API_BASE_URL?.trim() ?? "";
const websocketUrl =
  process.env.WEBSOCKET_URL?.trim() ||
  (apiBaseUrl ? `${apiBaseUrl.replace(/^http/, "ws")}/cable` : "");
const buildCommand = process.env.FRONTEND_BUILD_COMMAND?.trim() || "pnpm build";
const outputDirectory = process.env.FRONTEND_OUTPUT_DIRECTORY?.trim() || "dist";
const applicationName = process.env.APPLICATION_NAME?.trim() || "application";

if (!consumerFrontendDirectory) {
  throw new Error("CONSUMER_FRONTEND_DIRECTORY is required.");
}

if (environment !== "staging" && environment !== "production") {
  throw new Error("Frontend deployment stage must be staging or production.");
}

if (environment === "production" && frontendHostname && !certificateArn) {
  throw new Error("FRONTEND_CERTIFICATE_ARN is required for a custom production domain.");
}

export default $config({
  app(input: { stage?: string }) {
    return {
      name: `${applicationName}-frontend`,
      home: "aws",
      removal: input.stage === "production" ? "retain" : "remove",
      protect: input.stage === "production",
    };
  },
  run() {
    const environment = $app.stage;
    const site = new sst.aws.StaticSite(`${applicationName}-Frontend`, {
      path: consumerFrontendDirectory,
      build: {
        command: buildCommand,
        output: outputDirectory,
      },
      environment: {
        VITE_API_BASE_URL: apiBaseUrl,
        VITE_CABLE_URL: websocketUrl,
      },
      errorPage: "index.html",
      domain: frontendHostname
        ? {
            name: frontendHostname,
            dns: false,
            cert: certificateArn || undefined,
          }
        : undefined,
    });
    return {
      stage: environment,
      frontendUrl: site.url,
      frontendHostname,
      apiBaseUrl,
      websocketUrl,
    };
  },
});
