// In-memory storage for users
let users = [];
let idCounter = 1;

exports.handler = async (event) => {
    console.log("Received event:", JSON.stringify(event, null, 2));

    const path = event.rawPath; // API Gateway path
    const method = event.requestContext.http.method; // HTTP method
    const body = event.body ? JSON.parse(event.body) : null;
    let response;

    try {
        // Root path "/" returns hello
        if (path === "/") {
            response = {
                statusCode: 200,
                body: JSON.stringify({ message: "Hello from Lambda!" })
            };
        }
        // /user path handles CRUD
        else if (path === "/user") {
            switch (method) {

                // CREATE
                case "POST":
                    if (!body || !body.name) {
                        response = {
                            statusCode: 400,
                            body: JSON.stringify({ message: "Name is required" })
                        };
                        break;
                    }
                    const newUser = { id: idCounter++, name: body.name };
                    users.push(newUser);
                    response = {
                        statusCode: 201,
                        body: JSON.stringify({ message: "User created", user: newUser })
                    };
                    break;

                // READ
                case "GET":
                    response = {
                        statusCode: 200,
                        body: JSON.stringify({ users })
                    };
                    break;

                // UPDATE
                case "PUT":
                    if (!body || !body.id || !body.name) {
                        response = {
                            statusCode: 400,
                            body: JSON.stringify({ message: "id and name are required" })
                        };
                        break;
                    }
                    const userToUpdate = users.find(u => u.id === body.id);
                    if (!userToUpdate) {
                        response = {
                            statusCode: 404,
                            body: JSON.stringify({ message: "User not found" })
                        };
                        break;
                    }
                    userToUpdate.name = body.name;
                    response = {
                        statusCode: 200,
                        body: JSON.stringify({ message: "User updated", user: userToUpdate })
                    };
                    break;

                // DELETE
                case "DELETE":
                    if (!body || !body.id) {
                        response = {
                            statusCode: 400,
                            body: JSON.stringify({ message: "id is required" })
                        };
                        break;
                    }
                    const index = users.findIndex(u => u.id === body.id);
                    if (index === -1) {
                        response = {
                            statusCode: 404,
                            body: JSON.stringify({ message: "User not found" })
                        };
                        break;
                    }
                    const deletedUser = users.splice(index, 1);
                    response = {
                        statusCode: 200,
                        body: JSON.stringify({ message: "User deleted", user: deletedUser[0] })
                    };
                    break;

                default:
                    response = {
                        statusCode: 405,
                        body: JSON.stringify({ message: "Method not allowed" })
                    };
            }
        } else {
            response = {
                statusCode: 404,
                body: JSON.stringify({ message: "Route not found" })
            };
        }
    } catch (error) {
        console.error("Error:", error);
        response = {
            statusCode: 500,
            body: JSON.stringify({ message: "Internal server error", error: error.message })
        };
    }

    console.log("Response:", JSON.stringify(response, null, 2));
    return response;
};
