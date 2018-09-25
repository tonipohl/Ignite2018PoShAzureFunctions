# Communication

## Input

POST to Endpoint

``` json

{
    "QueueName" : "checkgroup"
}

```

## Output

every group retrieved as one queue element in the queue specified via post body.

``` json

{
        "GroupDisplayName" : "Testgruppe",
        "GroupId"          : "<guid>",
        "Groupmail"        : "<e-mail>"
}

```
