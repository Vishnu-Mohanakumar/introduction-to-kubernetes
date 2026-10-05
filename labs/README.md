# Labs

Three tiers of practice, in increasing scope:

- **[beginner/](./beginner/)** - the graded capstone assignment: build a full-stack Todo app on Kubernetes from scratch. Handed out on Day 2. See `beginner/LAB_QUESTIONS.md` and `beginner/LOCAL_ASSIGNMENT.md`.
- **[intermediate/](./intermediate/)** - optional, self-paced exercise: deploy the public Azure Voting App, find and fix 5 planted bugs across Deployments/Services/ConfigMap, then extend it (RBAC least-privilege, rolling update/rollback, scaling). No dependency on the capstone.
- **[advanced/](./advanced/)** - optional, self-paced exercise: the same app with Redis promoted to a StatefulSet and operational guardrails layered on (NetworkPolicy, HorizontalPodAutoscaler, PodDisruptionBudget, ResourceQuota/LimitRange), with 6 more bugs to find and fix. Independent of `intermediate/` - start here directly if you prefer.

Intermediate and advanced are independent of the capstone and of each other - work through whichever ones interest you, in any order. Try them yourself first (official docs, `kubectl explain`, trial and error) - reference solutions for all three tiers live in `../lab-solution/`.
