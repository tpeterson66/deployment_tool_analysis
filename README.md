# Deployment Tool Analysis

There are a few deployment tools available on the market today, this is a guided tour of both allowing everyone to form their own opinion of the tools.

## Tools

The tools we're looking at are Hashicorp Terrafrom Cloud, Env0, Spacelift, and Azure DevOps Pipelines

## Success Criteria

There are a few items that we need to evaluate to ensure we can use these tools at scale. Here is a list that I want to test across all the tools. In addition to that, I'm looking to get feedback on each tool on how they accomplish these items.

1. We need a supportable module registry. Ideally, we would have a version-able module that can be versioned seperately from the other modules. Generally, each repo becomes a module, which makes it difficult to manage long term
2. We need to be able to do automated tests against each module so that we can confirm the validity of each module and certifiy it.
3. We need to create multiple deployments of the same code to differenet environemtns. For example, a single terraform project deployed to dev, qa, and production with different variables for each environment.
4. Visually, we want to be able to clearly see the progression of the deployment. We also want to see clearly the changes that will occur in the environment if the plan is applied.
5. We need some support for GitOps, essentially, automatically do something on a commit.
6. We need the ability to run private nodes to support on-prem deployments and deployments behind private endpoint.
7. Need to be able to provide a list of users that can approve the deployment, policies around who/when/what can be applied
8. Infracost built in - track the cost increase for each environment based on changes. Track the environment after the deployment to true that up (this is a third-party product which will require a license outside the free tier)
9. Some level of drift detection, notification or alert if drift is detected.

## Wish List

1. The ability to deploy certain environments only off of tags
2. Notifications and interaction with Teams/Slack
3. It would be nice to run the local code against the running environment without having to do a commit and wait for a plan to get feedback. Ideally, that would mean that users would not even need TF running on their machine

## The Test Case

Run through all of the tools and test a deployment from this repo. Here are a few pointers:

1. You're going to need a service pricinipal for all of these tools (except one, one makes the app registration for you).
2. One of the tools allows you to pass a file to the deployment, so, you can uncomment the provisioner and add your SSH keys if you want
3. All the free tiers can be used to test the product. We're working on getting a paid trial for each tool for 14 days.

## Additional Comments

Keep note of things you like from each vendor, particually, items that one vendor does well compared to the others. Keep track of things you do not like about specific items as well. This will be helpful in evaluating these tools as a team at the end.
