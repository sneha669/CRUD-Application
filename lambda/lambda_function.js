// lambda_function.js
exports.handler = async (event) => {
    console.log("=== Incoming Event ===");
    console.log(JSON.stringify(event, null, 2));

    try {
        // Detect HTTP method (GET or POST)
        const method = event.requestContext?.http?.method || "UNKNOWN";
        console.log(`HTTP Method: ${method}`);

        // For GET requests — check query parameters
        if (method === "GET") {
            const queryParams = event.queryStringParameters || {};
            console.log("Query Params:", queryParams);

            const status = queryParams.status;

            if (status === "400") {
                console.warn("⚠️ Simulating Bad Request (400)");
                return {
                    statusCode: 400,
                    body: JSON.stringify({ error: "Bad Request - 400 Error" }),
                };
            } else if (status === "500") {
                console.error("💥 Simulating Internal Server Error (500)");
                throw new Error("Simulated Internal Server Error");
            }

            // Default success response for GET
            console.log("✅ GET request processed successfully");
            return {
                statusCode: 200,
                body: JSON.stringify({
                    message: "Hello from Lambda (GET)",
                    status: "success",
                }),
            };
        }

        // For POST requests — handle body
        if (method === "POST") {
            console.log("Processing POST request...");

            let bodyData;
            try {
                bodyData = JSON.parse(event.body);
            } catch (parseErr) {
                console.error("❌ Invalid JSON body received:", parseErr.message);
                return {
                    statusCode: 400,
                    body: JSON.stringify({
                        error: "Invalid JSON format in request body",
                        message: parseErr.message,
                    }),
                };
            }

            console.log("Received body:", bodyData);

            // Example: Validate required field
            if (!bodyData.name) {
                console.warn("⚠️ Missing required field: name");
                return {
                    statusCode: 400,
                    body: JSON.stringify({
                        error: "Missing 'name' field in JSON body",
                    }),
                };
            }

            // Simulate random server error for testing
            if (bodyData.name === "error") {
                console.error("💥 Simulated 500 error triggered");
                throw new Error("Forced internal error for testing");
            }

            // Success
            console.log("✅ POST processed successfully");
            return {
                statusCode: 200,
                body: JSON.stringify({
                    message: "POST request processed successfully",
                    receivedData: bodyData,
                }),
            };
        }

        // For unsupported methods
        console.warn("⚠️ Unsupported HTTP method received");
        return {
            statusCode: 405,
            body: JSON.stringify({
                error: "Method Not Allowed",
                allowedMethods: ["GET", "POST"],
            }),
        };
    } catch (err) {
        // Catch any unhandled errors
        console.error("💣 Unhandled exception caught:", err.message);
        return {
            statusCode: 500,
            body: JSON.stringify({
                error: "Internal Server Error",
                message: err.message,
            }),
        };
    }
};
