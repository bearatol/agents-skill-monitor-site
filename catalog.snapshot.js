// Original project catalog metadata. Paths are resolved within the source pack, not installed host paths.
window.SkillMonitorSnapshot = {
  "schema_version": 1,
  "mode": "catalog_snapshot",
  "source": "packs/agents-library/catalog/catalog.json",
  "version": "0.6.0",
  "captured_at": "2026-10-29T18:39:56+00:00",
  "scope": ".agents",
  "entries": [
    {
      "id": "rule:global-rules",
      "type": "rule",
      "name": "global-rules",
      "path": "packs/agents-library/library/rules/global-rules.md",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/rules/global-rules.md"
    },
    {
      "id": "agent:ceo",
      "type": "agent",
      "name": "ceo",
      "path": "packs/agents-library/library/agents/ceo.md",
      "description": "Coordinates skill-aware specialists, evidence, decisions, and ecosystem health.",
      "requires": [
        "skill:ceo",
        "orchestration:protocols",
        "tool:team"
      ],
      "recommended_skills": [
        "skill:ceo",
        "skill:skill-router",
        "skill:context-engineering"
      ],
      "capabilities": [
        "decomposition",
        "delegation",
        "integration",
        "verification"
      ],
      "access": "read-only",
      "catalog_path": "library/agents/ceo.md"
    },
    {
      "id": "agent:security-reviewer",
      "type": "agent",
      "name": "security-reviewer",
      "path": "packs/agents-library/library/agents/security-reviewer.md",
      "description": "Performs independent read-only security and provenance reviews.",
      "recommended_skills": [],
      "capabilities": [
        "security-review",
        "provenance-review",
        "risk-triage"
      ],
      "access": "read-only",
      "requires": [],
      "catalog_path": "library/agents/security-reviewer.md"
    },
    {
      "id": "agent:ai-vulnerability-monitor",
      "type": "agent",
      "name": "ai-vulnerability-monitor",
      "path": "packs/agents-library/library/agents/ai-vulnerability-monitor.md",
      "description": "Reviews the exact final AI-authored diff for introduced vulnerabilities.",
      "recommended_skills": [],
      "capabilities": [
        "diff-security-review",
        "secret-exposure-review",
        "regression-review"
      ],
      "access": "read-only",
      "requires": [],
      "catalog_path": "library/agents/ai-vulnerability-monitor.md"
    },
    {
      "id": "agent:marketer",
      "type": "agent",
      "name": "marketer",
      "path": "packs/agents-library/library/agents/marketer.md",
      "description": "Coordinates evidence-based marketing strategy, assets, channels, and measurement.",
      "recommended_skills": [
        "skill:market-research",
        "skill:positioning",
        "skill:campaign-launch"
      ],
      "capabilities": [
        "market-research",
        "positioning",
        "campaign-planning",
        "measurement"
      ],
      "access": "read-only",
      "requires": [],
      "catalog_path": "library/agents/marketer.md"
    },
    {
      "id": "agent:design-reviewer",
      "type": "agent",
      "name": "design-reviewer",
      "path": "packs/agents-library/library/agents/design-reviewer.md",
      "description": "Reviews interfaces for usability, hierarchy, accessibility, and coherence.",
      "recommended_skills": [
        "skill:ui-ux-design",
        "skill:quality-review"
      ],
      "capabilities": [
        "ux-review",
        "accessibility-review",
        "design-system-review"
      ],
      "access": "read-only",
      "requires": [],
      "catalog_path": "library/agents/design-reviewer.md"
    },
    {
      "id": "agent:video-producer",
      "type": "agent",
      "name": "video-producer",
      "path": "packs/agents-library/library/agents/video-producer.md",
      "description": "Plans and implements programmatic video deliverables.",
      "recommended_skills": [
        "skill:remotion-video",
        "skill:brand-voice"
      ],
      "capabilities": [
        "video-planning",
        "motion-design",
        "remotion-implementation"
      ],
      "access": "workspace-write",
      "requires": [],
      "catalog_path": "library/agents/video-producer.md"
    },
    {
      "id": "agent:context-engineer",
      "type": "agent",
      "name": "context-engineer",
      "path": "packs/agents-library/library/agents/context-engineer.md",
      "description": "Builds compact, reliable context packets and handoffs.",
      "recommended_skills": [
        "skill:context-engineering",
        "skill:quality-review"
      ],
      "capabilities": [
        "context-audit",
        "compression",
        "handoff-design"
      ],
      "access": "read-only",
      "requires": [],
      "catalog_path": "library/agents/context-engineer.md"
    },
    {
      "id": "agent:engineer",
      "type": "agent",
      "name": "engineer",
      "path": "packs/agents-library/library/agents/engineer.md",
      "description": "Implements bounded software changes and returns tested evidence.",
      "recommended_skills": [
        "skill:software-delivery",
        "skill:quality-review"
      ],
      "capabilities": [
        "implementation",
        "refactoring",
        "testing",
        "debugging"
      ],
      "access": "workspace-write",
      "requires": [],
      "catalog_path": "library/agents/engineer.md"
    },
    {
      "id": "agent:qa-reviewer",
      "type": "agent",
      "name": "qa-reviewer",
      "path": "packs/agents-library/library/agents/qa-reviewer.md",
      "description": "Independently verifies requirements, regressions, and release evidence.",
      "recommended_skills": [
        "skill:quality-review"
      ],
      "capabilities": [
        "acceptance-review",
        "regression-review",
        "edge-case-analysis"
      ],
      "access": "read-only",
      "requires": [],
      "catalog_path": "library/agents/qa-reviewer.md"
    },
    {
      "id": "agent:product-editor",
      "type": "agent",
      "name": "product-editor",
      "path": "packs/agents-library/library/agents/product-editor.md",
      "description": "Improves user-facing product structure, copy, and documentation.",
      "recommended_skills": [
        "skill:natural-writing",
        "skill:copy-editing",
        "skill:brand-voice"
      ],
      "capabilities": [
        "information-architecture",
        "copy-editing",
        "documentation"
      ],
      "access": "workspace-write",
      "requires": [],
      "catalog_path": "library/agents/product-editor.md"
    },
    {
      "id": "agent:legal-content-reviewer",
      "type": "agent",
      "name": "legal-content-reviewer",
      "path": "packs/agents-library/library/agents/legal-content-reviewer.md",
      "description": "Reviews public claims, licensing, attribution, and compliance risk.",
      "recommended_skills": [
        "skill:copy-editing",
        "skill:quality-review"
      ],
      "capabilities": [
        "claims-review",
        "license-review",
        "compliance-triage"
      ],
      "access": "read-only",
      "requires": [],
      "catalog_path": "library/agents/legal-content-reviewer.md"
    },
    {
      "id": "agent:sales",
      "type": "agent",
      "name": "sales",
      "path": "packs/agents-library/library/agents/sales.md",
      "description": "Designs evidence-based offers, qualification, pipeline, and sales experiments.",
      "recommended_skills": [
        "skill:offer-design",
        "skill:positioning",
        "skill:messaging"
      ],
      "capabilities": [
        "qualification",
        "offer-design",
        "pipeline-design",
        "objection-handling"
      ],
      "access": "read-only",
      "requires": [],
      "catalog_path": "library/agents/sales.md"
    },
    {
      "id": "agent:seo-researcher",
      "type": "agent",
      "name": "seo-researcher",
      "path": "packs/agents-library/library/agents/seo-researcher.md",
      "description": "Reviews search demand, intent, information architecture, and technical SEO evidence.",
      "recommended_skills": [
        "skill:market-research",
        "skill:content-strategy",
        "skill:quality-review"
      ],
      "capabilities": [
        "search-intent",
        "content-opportunity",
        "technical-seo-review",
        "measurement"
      ],
      "access": "read-only",
      "requires": [],
      "catalog_path": "library/agents/seo-researcher.md"
    },
    {
      "id": "orchestration:protocols",
      "type": "orchestration",
      "name": "protocols",
      "path": "packs/agents-library/library/orchestration",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/orchestration"
    },
    {
      "id": "tool:team",
      "type": "tool",
      "name": "team",
      "path": "packs/agents-library/library/tools/team",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/tools/team"
    },
    {
      "id": "skill:ceo",
      "type": "skill",
      "name": "ceo",
      "path": "packs/agents-library/library/skills/ceo",
      "requires": [
        "orchestration:protocols",
        "tool:team"
      ],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/ceo"
    },
    {
      "id": "skill:skill-router",
      "type": "skill",
      "name": "skill-router",
      "path": "packs/agents-library/library/skills/skill-router",
      "requires": [
        "skill:capability-discovery"
      ],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/skill-router"
    },
    {
      "id": "skill:capability-discovery",
      "type": "skill",
      "name": "capability-discovery",
      "path": "packs/agents-library/library/skills/capability-discovery",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/capability-discovery"
    },
    {
      "id": "skill:skill-authoring",
      "type": "skill",
      "name": "skill-authoring",
      "path": "packs/agents-library/library/skills/skill-authoring",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/skill-authoring"
    },
    {
      "id": "skill:security-gate",
      "type": "skill",
      "name": "security-gate",
      "path": "packs/agents-library/library/skills/security-gate",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/security-gate"
    },
    {
      "id": "skill:natural-writing",
      "type": "skill",
      "name": "natural-writing",
      "path": "packs/agents-library/library/skills/natural-writing",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/natural-writing"
    },
    {
      "id": "skill:software-delivery",
      "type": "skill",
      "name": "software-delivery",
      "path": "packs/agents-library/library/skills/software-delivery",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/software-delivery"
    },
    {
      "id": "skill:quality-review",
      "type": "skill",
      "name": "quality-review",
      "path": "packs/agents-library/library/skills/quality-review",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/quality-review"
    },
    {
      "id": "skill:context-engineering",
      "type": "skill",
      "name": "context-engineering",
      "path": "packs/agents-library/library/skills/context-engineering",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/context-engineering"
    },
    {
      "id": "skill:ui-ux-design",
      "type": "skill",
      "name": "ui-ux-design",
      "path": "packs/agents-library/library/skills/ui-ux-design",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/ui-ux-design"
    },
    {
      "id": "skill:remotion-video",
      "type": "skill",
      "name": "remotion-video",
      "path": "packs/agents-library/library/skills/remotion-video",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/remotion-video"
    },
    {
      "id": "skill:market-research",
      "type": "skill",
      "name": "market-research",
      "path": "packs/agents-library/library/skills/market-research",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/market-research"
    },
    {
      "id": "skill:audience-segmentation",
      "type": "skill",
      "name": "audience-segmentation",
      "path": "packs/agents-library/library/skills/audience-segmentation",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/audience-segmentation"
    },
    {
      "id": "skill:customer-interviews",
      "type": "skill",
      "name": "customer-interviews",
      "path": "packs/agents-library/library/skills/customer-interviews",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/customer-interviews"
    },
    {
      "id": "skill:positioning",
      "type": "skill",
      "name": "positioning",
      "path": "packs/agents-library/library/skills/positioning",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/positioning"
    },
    {
      "id": "skill:messaging",
      "type": "skill",
      "name": "messaging",
      "path": "packs/agents-library/library/skills/messaging",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/messaging"
    },
    {
      "id": "skill:offer-design",
      "type": "skill",
      "name": "offer-design",
      "path": "packs/agents-library/library/skills/offer-design",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/offer-design"
    },
    {
      "id": "skill:brand-voice",
      "type": "skill",
      "name": "brand-voice",
      "path": "packs/agents-library/library/skills/brand-voice",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/brand-voice"
    },
    {
      "id": "skill:copywriting",
      "type": "skill",
      "name": "copywriting",
      "path": "packs/agents-library/library/skills/copywriting",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/copywriting"
    },
    {
      "id": "skill:copy-editing",
      "type": "skill",
      "name": "copy-editing",
      "path": "packs/agents-library/library/skills/copy-editing",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/copy-editing"
    },
    {
      "id": "skill:landing-page",
      "type": "skill",
      "name": "landing-page",
      "path": "packs/agents-library/library/skills/landing-page",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/landing-page"
    },
    {
      "id": "skill:email-strategy",
      "type": "skill",
      "name": "email-strategy",
      "path": "packs/agents-library/library/skills/email-strategy",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/email-strategy"
    },
    {
      "id": "skill:welcome-sequence",
      "type": "skill",
      "name": "welcome-sequence",
      "path": "packs/agents-library/library/skills/welcome-sequence",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/welcome-sequence"
    },
    {
      "id": "skill:nurture-sequence",
      "type": "skill",
      "name": "nurture-sequence",
      "path": "packs/agents-library/library/skills/nurture-sequence",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/nurture-sequence"
    },
    {
      "id": "skill:launch-email",
      "type": "skill",
      "name": "launch-email",
      "path": "packs/agents-library/library/skills/launch-email",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/launch-email"
    },
    {
      "id": "skill:cold-email",
      "type": "skill",
      "name": "cold-email",
      "path": "packs/agents-library/library/skills/cold-email",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/cold-email"
    },
    {
      "id": "skill:newsletter",
      "type": "skill",
      "name": "newsletter",
      "path": "packs/agents-library/library/skills/newsletter",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/newsletter"
    },
    {
      "id": "skill:ad-strategy",
      "type": "skill",
      "name": "ad-strategy",
      "path": "packs/agents-library/library/skills/ad-strategy",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/ad-strategy"
    },
    {
      "id": "skill:ad-creative",
      "type": "skill",
      "name": "ad-creative",
      "path": "packs/agents-library/library/skills/ad-creative",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/ad-creative"
    },
    {
      "id": "skill:content-strategy",
      "type": "skill",
      "name": "content-strategy",
      "path": "packs/agents-library/library/skills/content-strategy",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/content-strategy"
    },
    {
      "id": "skill:social-content",
      "type": "skill",
      "name": "social-content",
      "path": "packs/agents-library/library/skills/social-content",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/social-content"
    },
    {
      "id": "skill:lead-magnet",
      "type": "skill",
      "name": "lead-magnet",
      "path": "packs/agents-library/library/skills/lead-magnet",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/lead-magnet"
    },
    {
      "id": "skill:cro-audit",
      "type": "skill",
      "name": "cro-audit",
      "path": "packs/agents-library/library/skills/cro-audit",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/cro-audit"
    },
    {
      "id": "skill:campaign-launch",
      "type": "skill",
      "name": "campaign-launch",
      "path": "packs/agents-library/library/skills/campaign-launch",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/skills/campaign-launch"
    },
    {
      "id": "model:mlx-local-runtime",
      "type": "model",
      "name": "mlx-local-runtime",
      "path": "packs/agents-library/library/models/mlx-local-runtime",
      "requires": [],
      "recommended_skills": [],
      "capabilities": [],
      "description": "",
      "access": "unknown",
      "catalog_path": "library/models/mlx-local-runtime"
    }
  ],
  "relationships": [
    {
      "from": "agent:ceo",
      "to": "skill:ceo",
      "kind": "requires"
    },
    {
      "from": "agent:ceo",
      "to": "orchestration:protocols",
      "kind": "requires"
    },
    {
      "from": "agent:ceo",
      "to": "tool:team",
      "kind": "requires"
    },
    {
      "from": "agent:ceo",
      "to": "skill:ceo",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:ceo",
      "to": "skill:skill-router",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:ceo",
      "to": "skill:context-engineering",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:marketer",
      "to": "skill:market-research",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:marketer",
      "to": "skill:positioning",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:marketer",
      "to": "skill:campaign-launch",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:design-reviewer",
      "to": "skill:ui-ux-design",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:design-reviewer",
      "to": "skill:quality-review",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:video-producer",
      "to": "skill:remotion-video",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:video-producer",
      "to": "skill:brand-voice",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:context-engineer",
      "to": "skill:context-engineering",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:context-engineer",
      "to": "skill:quality-review",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:engineer",
      "to": "skill:software-delivery",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:engineer",
      "to": "skill:quality-review",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:qa-reviewer",
      "to": "skill:quality-review",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:product-editor",
      "to": "skill:natural-writing",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:product-editor",
      "to": "skill:copy-editing",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:product-editor",
      "to": "skill:brand-voice",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:legal-content-reviewer",
      "to": "skill:copy-editing",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:legal-content-reviewer",
      "to": "skill:quality-review",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:sales",
      "to": "skill:offer-design",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:sales",
      "to": "skill:positioning",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:sales",
      "to": "skill:messaging",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:seo-researcher",
      "to": "skill:market-research",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:seo-researcher",
      "to": "skill:content-strategy",
      "kind": "recommended_skill"
    },
    {
      "from": "agent:seo-researcher",
      "to": "skill:quality-review",
      "kind": "recommended_skill"
    },
    {
      "from": "skill:ceo",
      "to": "orchestration:protocols",
      "kind": "requires"
    },
    {
      "from": "skill:ceo",
      "to": "tool:team",
      "kind": "requires"
    },
    {
      "from": "skill:skill-router",
      "to": "skill:capability-discovery",
      "kind": "requires"
    }
  ],
  "diagnostics": [],
  "security": {
    "state": "not_run",
    "reason": "independent_review_required"
  },
  "executor": {
    "state": "unavailable",
    "reason": "independent_review_required"
  }
};
