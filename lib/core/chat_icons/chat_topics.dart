import 'package:flutter/material.dart';

/// One topic a chat can be about: the Material icon name Hermes answers with,
/// the rounded icon drawn for it, and the title words that suggest it on the
/// device.
@immutable
class ChatTopic {
  const ChatTopic(this.name, this.icon, this.keywords);

  /// The Material Symbols name, as Hermes is asked to reply with it.
  final String name;
  final IconData icon;

  /// Lower-case words or phrases. A phrase (with a space) matches only as a
  /// whole; a single word also matches its plural and, from five letters,
  /// longer words it starts (`print` → `printing`).
  final List<String> keywords;
}

/// The topics a chat icon can show, about 190 of them (design D1). Order is
/// the tie-break: problems and actions first, then subjects, then the
/// generic ones, so "Update Claude Code" reads as an update before code.
// dart format off
const List<ChatTopic> chatTopics = [
  // Problems and actions.
  ChatTopic('bug_report', Icons.bug_report_rounded, [
    'bug', 'error', 'crash', 'crashes', 'crashing', 'broken', 'failing',
    'failed', 'failure', 'exception', 'debug', 'debugging', 'regression',
    'not loading', 'not working', 'doesn\'t work', 'stuck', 'hang',
  ]),
  ChatTopic('warning', Icons.warning_rounded, [
    'warning', 'outage', 'incident', 'down', 'danger', 'risk', 'emergency',
  ]),
  ChatTopic('system_update', Icons.system_update_rounded, [
    'update', 'upgrade', 'upgrading', 'install', 'installing', 'installation',
    'version', 'patch', 'changelog',
  ]),
  ChatTopic('rocket_launch', Icons.rocket_launch_rounded, [
    'deploy', 'deployment', 'launch', 'release', 'ship', 'shipping it',
    'publish', 'rollout',
  ]),
  ChatTopic('cloud_sync', Icons.cloud_sync_rounded, [
    'backup', 'restic', 'rsync', 'snapshot', 'restore', 'time machine',
  ]),
  ChatTopic('sync', Icons.sync_rounded, [
    'sync', 'syncing', 'synchronise', 'synchronize', 'mirror',
  ]),
  ChatTopic('compare_arrows', Icons.compare_arrows_rounded, [
    'vs', 'versus', 'compare', 'comparison', 'comparing', 'difference',
    'alternative', 'alternatives', 'better than',
  ]),
  ChatTopic('swap_horiz', Icons.swap_horiz_rounded, [
    'migrate', 'migration', 'convert', 'conversion', 'switch to', 'move to',
    'port to',
  ]),
  ChatTopic('summarize', Icons.summarize_rounded, [
    'summary', 'summarize', 'summarise', 'tldr', 'recap', 'digest',
  ]),
  ChatTopic('translate', Icons.translate_rounded, [
    'translate', 'translation', 'spanish', 'french', 'german', 'japanese',
    'chinese', 'localisation', 'localization', 'l10n',
  ]),
  ChatTopic('speed', Icons.speed_rounded, [
    'performance', 'slow', 'speed', 'latency', 'optimise', 'optimize',
    'optimization', 'optimisation', 'benchmark', 'faster',
  ]),
  ChatTopic('delete', Icons.delete_rounded, [
    'delete', 'remove', 'cleanup', 'clean up', 'uninstall', 'purge', 'prune',
  ]),
  ChatTopic('fact_check', Icons.fact_check_rounded, [
    'audit', 'checks', 'qa', 'test', 'tests', 'testing', 'fact check',
    'validate', 'validation', 'verify',
  ]),
  ChatTopic('rate_review', Icons.rate_review_rounded, [
    'review', 'feedback', 'critique', 'code review',
  ]),
  ChatTopic('edit_note', Icons.edit_note_rounded, [
    'write', 'writing', 'draft', 'essay', 'blog', 'article', 'rewrite',
    'copywriting', 'story', 'poem',
  ]),
  ChatTopic('spellcheck', Icons.spellcheck_rounded, [
    'grammar', 'proofread', 'spelling', 'typo', 'typos',
  ]),

  // Servers, code and devices.
  ChatTopic('dns', Icons.dns_rounded, [
    'server', 'dns', 'host', 'hosting', 'vps', 'nas', 'proxmox', 'homelab',
    'home lab', 'uptime', 'daemon', 'systemd', 'docker', 'container',
    'kubernetes', 'k8s', 'miniserver', 'unraid', 'truenas',
  ]),
  ChatTopic('terminal', Icons.terminal_rounded, [
    'terminal', 'shell', 'bash', 'zsh', 'cli', 'command', 'commands', 'ssh',
    'tmux', 'script', 'codex',
  ]),
  ChatTopic('code', Icons.code_rounded, [
    'code', 'coding', 'programming', 'refactor', 'function', 'repo',
    'repository', 'github', 'git', 'commit', 'branch', 'merge', 'flutter',
    'dart', 'python', 'rust', 'javascript', 'typescript', 'kotlin', 'swift',
    'compile', 'gradle', 'xcode', 'sdk',
  ]),
  ChatTopic('data_object', Icons.data_object_rounded, [
    'json', 'yaml', 'toml', 'schema', 'regex', 'xml',
  ]),
  ChatTopic('api', Icons.api_rounded, [
    'api', 'endpoint', 'endpoints', 'webhook', 'rest', 'graphql', 'openapi',
  ]),
  ChatTopic('hub', Icons.hub_rounded, [
    'integration', 'integrations', 'connector', 'connectors', 'mcp', 'hub',
  ]),
  ChatTopic('account_tree', Icons.account_tree_rounded, [
    'architecture', 'structure', 'hierarchy', 'diagram', 'org chart',
    'workflow',
  ]),
  ChatTopic('table_chart', Icons.table_chart_rounded, [
    'database', 'sql', 'postgres', 'postgresql', 'sqlite', 'mysql', 'table',
    'spreadsheet', 'csv', 'excel', 'sheets',
  ]),
  ChatTopic('storage', Icons.storage_rounded, [
    'disk', 'drive', 'ssd', 'hdd', 'raid', 'zfs', 'volume', 'storage',
    'partition',
  ]),
  ChatTopic('cloud', Icons.cloud_rounded, [
    'cloud', 'aws', 'gcp', 'azure', 's3', 'cloudflare', 'bucket',
  ]),
  ChatTopic('vpn_lock', Icons.vpn_lock_rounded, [
    'vpn', 'tailscale', 'wireguard', 'zerotier', 'headscale',
  ]),
  ChatTopic('router', Icons.router_rounded, [
    'network', 'networking', 'router', 'lan', 'ip', 'port', 'ports', 'dhcp',
    'firewall', 'subnet', 'mesh', 'unifi',
  ]),
  ChatTopic('wifi', Icons.wifi_rounded, ['wifi', 'wi-fi', 'wireless']),
  ChatTopic('bluetooth', Icons.bluetooth_rounded, [
    'bluetooth', 'pairing', 'earbuds', 'airpods',
  ]),
  ChatTopic('usb', Icons.usb_rounded, ['usb', 'cable', 'adapter', 'dongle']),
  ChatTopic('signal_cellular_alt', Icons.signal_cellular_alt_rounded, [
    'cellular', 'carrier', 'sim', 'esim', '5g', 'lte', 'signal strength',
    'data plan', 'roaming',
  ]),
  ChatTopic('key', Icons.key_rounded, [
    'key', 'api key', 'token', 'credential', 'credentials', 'secret',
    'secrets', 'passkey', 'ssh key',
  ]),
  ChatTopic('security', Icons.security_rounded, [
    'security', 'secure', 'auth', 'authentication', 'password', '2fa', 'mfa',
    'permission', 'permissions', 'encrypt', 'encryption', 'malware', 'virus',
    'phishing', 'scam',
  ]),
  ChatTopic('lock', Icons.lock_rounded, ['lock', 'locked', 'privacy']),
  ChatTopic('smart_toy', Icons.smart_toy_rounded, [
    'agent', 'bot', 'assistant', 'ai', 'llm', 'gpt', 'chatgpt', 'claude',
    'hermes', 'gemini', 'ollama', 'openai', 'anthropic', 'chatbot',
  ]),
  ChatTopic('psychology', Icons.psychology_rounded, [
    'prompt', 'prompts', 'reasoning', 'thinking', 'psychology', 'mindset',
  ]),
  ChatTopic('auto_awesome', Icons.auto_awesome_rounded, [
    'generate', 'generated', 'generation', 'magic', 'ai art', 'midjourney',
    'stable diffusion',
  ]),
  ChatTopic('memory', Icons.memory_rounded, [
    'ram', 'cpu', 'gpu', 'hardware', 'chip', 'processor', 'overclock',
  ]),
  ChatTopic('developer_board', Icons.developer_board_rounded, [
    'raspberry', 'arduino', 'esp32', 'esphome', 'firmware', 'microcontroller',
    'pcb', 'circuit', 'soldering',
  ]),
  ChatTopic('auto_mode', Icons.auto_mode_rounded, [
    'automation', 'automate', 'automations', 'routine', 'routines',
    'shortcut', 'shortcuts', 'zapier', 'n8n',
  ]),
  ChatTopic('handyman', Icons.handyman_rounded, [
    'tools', 'tool', 'toolset', 'toolsets', 'skill', 'skills', 'plugin',
    'plugins',
  ]),
  ChatTopic('extension', Icons.extension_rounded, [
    'extension', 'extensions', 'addon', 'add-on', 'mod', 'mods',
  ]),
  ChatTopic('monitor_heart', Icons.monitor_heart_rounded, [
    'monitoring', 'monitor', 'health check', 'alerting', 'observability',
    'grafana', 'prometheus',
  ]),
  ChatTopic('history', Icons.history_rounded, [
    'history', 'log', 'logs', 'audit log', 'changes',
  ]),
  ChatTopic('dashboard', Icons.dashboard_rounded, [
    'dashboard', 'dashboards', 'overview', 'homepage', 'widget', 'widgets',
  ]),
  ChatTopic('web', Icons.web_rounded, [
    'webui', 'frontend', 'front end', 'ui', 'ux', 'interface',
    'page', 'screen',
  ]),
  ChatTopic('language', Icons.language_rounded, [
    'website', 'web', 'browser', 'html', 'css', 'domain', 'http', 'https',
    'chrome', 'firefox', 'safari', 'url', 'seo',
  ]),
  ChatTopic('link', Icons.link_rounded, ['link', 'links', 'redirect']),
  ChatTopic('rss_feed', Icons.rss_feed_rounded, [
    'rss', 'feed', 'feeds', 'subscribe', 'subscription feed',
  ]),
  ChatTopic('phone_android', Icons.phone_android_rounded, [
    'android', 'phone', 'apk', 'mobile', 'app', 'pixel', 'fold', 'samsung',
    'galaxy', 'oneplus',
  ]),
  ChatTopic('phone_iphone', Icons.phone_iphone_rounded, [
    'iphone', 'ios', 'ipad', 'apple watch', 'testflight',
  ]),
  ChatTopic('tablet_android', Icons.tablet_android_rounded, [
    'tablet', 'kindle fire', 'fire hd',
  ]),
  ChatTopic('laptop_mac', Icons.laptop_mac_rounded, [
    'mac', 'macbook', 'laptop', 'macos', 'imac', 'finder',
  ]),
  ChatTopic('computer', Icons.computer_rounded, [
    'pc', 'desktop', 'windows', 'linux', 'ubuntu', 'debian', 'arch',
    'computer', 'monitor setup',
  ]),
  ChatTopic('keyboard', Icons.keyboard_rounded, [
    'keyboard', 'keyboards', 'typing', 'keybinding', 'keybindings', 'hotkey',
  ]),
  ChatTopic('watch', Icons.watch_rounded, [
    'watch', 'smartwatch', 'wear os', 'wearos', 'garmin', 'fitbit',
  ]),
  ChatTopic('tv', Icons.tv_rounded, [
    'tv', 'television', 'chromecast', 'roku', 'apple tv', 'shield',
  ]),
  ChatTopic('speaker', Icons.speaker_rounded, [
    'speaker', 'speakers', 'sonos', 'soundbar', 'hifi', 'amplifier',
  ]),
  ChatTopic('devices', Icons.devices_rounded, ['devices', 'device', 'gadget']),
  ChatTopic('qr_code', Icons.qr_code_rounded, ['qr', 'barcode', 'scan']),

  // Making things.
  ChatTopic('print', Icons.print_rounded, [
    'print', 'printer', 'printing', 'bambu', 'prusa', 'slicer', 'slice',
    'slicing', 'filament', '3d print', 'nozzle',
  ]),
  ChatTopic('view_in_ar', Icons.view_in_ar_rounded, [
    '3d', 'cad', 'stl', 'mesh', 'blender', 'fusion', 'onshape', 'openscad',
    'grip', 'enclosure', 'bracket',
  ]),
  ChatTopic('straighten', Icons.straighten_rounded, [
    'measure', 'measurement', 'measurements', 'dimensions', 'tolerance',
    'calibrate', 'calibration',
  ]),
  ChatTopic('construction', Icons.construction_rounded, [
    'construction', 'renovation', 'repair', 'repairs', 'diy', 'remodel',
    'drill', 'woodworking',
  ]),
  ChatTopic('chair', Icons.chair_rounded, [
    'furniture', 'desk', 'chair', 'sofa', 'couch', 'ikea', 'shelf',
  ]),
  ChatTopic('palette', Icons.palette_rounded, [
    'design', 'color', 'colors', 'colour', 'colours', 'theme', 'themes',
    'palette', 'style', 'styling', 'figma', 'mockup', 'logo', 'branding',
    'material you',
  ]),
  ChatTopic('brush', Icons.brush_rounded, [
    'drawing', 'draw', 'art', 'paint', 'painting', 'sketch', 'illustration',
  ]),
  ChatTopic('photo_camera', Icons.photo_camera_rounded, [
    'photo', 'camera', 'picture', 'image', 'photography', 'immich', 'lens',
    'wallpaper', 'screenshot',
  ]),
  ChatTopic('videocam', Icons.videocam_rounded, [
    'video', 'youtube', 'stream', 'streaming', 'recording', 'webcam', 'obs',
  ]),
  ChatTopic('slideshow', Icons.slideshow_rounded, [
    'slides', 'presentation', 'deck', 'keynote', 'powerpoint',
  ]),
  ChatTopic('description', Icons.description_rounded, [
    'document', 'doc', 'docs', 'pdf', 'readme', 'report', 'docx', 'resume',
    'cv', 'letter',
  ]),
  ChatTopic('sticky_note_2', Icons.sticky_note_2_rounded, [
    'note', 'notes', 'obsidian', 'journal', 'notion', 'memo',
  ]),

  // Learning and ideas.
  ChatTopic('school', Icons.school_rounded, [
    'learn', 'learning', 'course', 'study', 'studying', 'school', 'class',
    'lesson', 'tutorial', 'homework', 'university', 'college',
  ]),
  ChatTopic('menu_book', Icons.menu_book_rounded, [
    'book', 'reading', 'kindle', 'novel', 'wiki', 'chapter', 'audiobook',
  ]),
  ChatTopic('quiz', Icons.quiz_rounded, ['quiz', 'trivia', 'exam', 'puzzle']),
  ChatTopic('science', Icons.science_rounded, [
    'science', 'experiment', 'lab', 'chemistry', 'physics', 'astronomy',
  ]),
  ChatTopic('biotech', Icons.biotech_rounded, [
    'biology', 'dna', 'genetics', 'genome', 'microscope',
  ]),
  ChatTopic('calculate', Icons.calculate_rounded, [
    'math', 'maths', 'calculate', 'calculation', 'formula', 'equation',
    'calculator', 'statistics',
  ]),
  ChatTopic('lightbulb', Icons.lightbulb_rounded, [
    'idea', 'ideas', 'brainstorm', 'brainstorming', 'concept', 'suggestion',
    'suggestions', 'tips', 'inspiration',
  ]),
  ChatTopic('travel_explore', Icons.travel_explore_rounded, [
    'research', 'explore', 'discover', 'investigate', 'deep dive',
  ]),
  ChatTopic('flag', Icons.flag_rounded, [
    'goal', 'goals', 'okr', 'okrs', 'milestone', 'milestones', 'objective',
    'resolution',
  ]),
  ChatTopic('timeline', Icons.timeline_rounded, [
    'roadmap', 'timeline', 'phases', 'gantt',
  ]),
  ChatTopic('checklist', Icons.checklist_rounded, [
    'todo', 'to-do', 'checklist', 'tasks', 'task', 'backlog', 'beads',
    'chores list',
  ]),
  ChatTopic('task_alt', Icons.task_alt_rounded, [
    'done', 'complete', 'completed', 'finish', 'finished',
  ]),
  ChatTopic('inventory_2', Icons.inventory_2_rounded, [
    'inventory', 'archive', 'archives', 'organize', 'organise', 'sort',
    'sorting', 'filing', 'declutter',
  ]),
  ChatTopic('folder', Icons.folder_rounded, [
    'folder', 'folders', 'file', 'files', 'directory', 'project files',
  ]),
  ChatTopic('bookmark', Icons.bookmark_rounded, [
    'bookmark', 'bookmarks', 'read later', 'reading list',
  ]),
  ChatTopic('bar_chart', Icons.bar_chart_rounded, [
    'chart', 'charts', 'graph', 'data', 'stats', 'analytics', 'metrics',
    'kpi', 'visualization', 'visualisation',
  ]),
  ChatTopic('trending_up', Icons.trending_up_rounded, [
    'stocks', 'stock', 'market', 'markets', 'growth', 'portfolio', 'etf',
    'investing', 'invest', 'investment',
  ]),

  // Money and work.
  ChatTopic('currency_bitcoin', Icons.currency_bitcoin_rounded, [
    'bitcoin', 'crypto', 'ethereum', 'blockchain', 'wallet address',
  ]),
  ChatTopic('request_quote', Icons.request_quote_rounded, [
    'budget', 'budgets', 'quote', 'estimate', 'expense', 'expenses',
    'spending', 'quarterly',
  ]),
  ChatTopic('receipt_long', Icons.receipt_long_rounded, [
    'receipt', 'receipts', 'tax return', 'reimbursement',
  ]),
  ChatTopic('account_balance', Icons.account_balance_rounded, [
    'bank', 'banking', 'finance', 'finances', 'tax', 'taxes', 'loan',
    'mortgage', 'irs', 'hmrc', 'accounting',
  ]),
  ChatTopic('savings', Icons.savings_rounded, [
    'savings', 'save money', 'retirement', 'pension', '401k', 'ira',
  ]),
  ChatTopic('credit_card', Icons.credit_card_rounded, [
    'credit card', 'debit', 'card', 'cards', 'apple pay', 'google pay',
  ]),
  ChatTopic('payments', Icons.payments_rounded, [
    'money', 'payment', 'pay', 'bill', 'bills', 'invoice', 'invoices',
    'price', 'cost', 'costs', 'refund', 'salary',
  ]),
  ChatTopic('workspace_premium', Icons.workspace_premium_rounded, [
    'subscription', 'subscriptions', 'premium', 'pricing', 'plan tier',
    'membership',
  ]),
  ChatTopic('sell', Icons.sell_rounded, [
    'sell', 'selling', 'ebay', 'marketplace', 'listing', 'resale',
  ]),
  ChatTopic('storefront', Icons.storefront_rounded, [
    'store', 'shop', 'business', 'ecommerce', 'shopify', 'etsy', 'startup',
  ]),
  ChatTopic('campaign', Icons.campaign_rounded, [
    'marketing', 'campaign', 'ads', 'advertising', 'promotion',
    'social media', 'announcement',
  ]),
  ChatTopic('gavel', Icons.gavel_rounded, [
    'legal', 'law', 'lawyer', 'contract', 'contracts', 'court', 'nda',
    'terms', 'lawsuit', 'license', 'licence',
  ]),
  ChatTopic('policy', Icons.policy_rounded, [
    'policy', 'policies', 'compliance', 'gdpr', 'regulation',
  ]),
  ChatTopic('handshake', Icons.handshake_rounded, [
    'deal', 'negotiation', 'negotiate', 'partnership', 'agreement',
  ]),
  ChatTopic('work', Icons.work_rounded, [
    'work', 'job', 'jobs', 'career', 'interview', 'hiring', 'office',
    'manager', 'promotion review', 'linkedin',
  ]),
  ChatTopic('support_agent', Icons.support_agent_rounded, [
    'support', 'helpdesk', 'customer service', 'customer',
  ]),
  ChatTopic('groups', Icons.groups_rounded, [
    'team', 'teams', 'people', 'meetup', 'community', 'club',
  ]),
  ChatTopic('person', Icons.person_rounded, [
    'profile', 'person', 'contact', 'contacts', 'user', 'account', 'bio',
  ]),

  // Communication.
  ChatTopic('mail', Icons.mail_rounded, [
    'email', 'mail', 'inbox', 'gmail', 'fastmail', 'newsletter', 'outlook',
  ]),
  ChatTopic('chat', Icons.chat_rounded, [
    'message', 'messages', 'slack', 'discord', 'telegram', 'signal',
    'whatsapp', 'sms', 'imessage', 'text message',
  ]),
  ChatTopic('forum', Icons.forum_rounded, [
    'discussion', 'thread', 'forum', 'reddit', 'debate',
  ]),
  ChatTopic('call', Icons.call_rounded, ['call', 'calls', 'phone call']),
  ChatTopic('notifications', Icons.notifications_rounded, [
    'notification', 'notifications', 'alert', 'alerts', 'push', 'ntfy',
  ]),
  ChatTopic('share', Icons.share_rounded, ['share', 'sharing']),
  ChatTopic('mic', Icons.mic_rounded, [
    'voice', 'dictation', 'microphone', 'speech', 'tts', 'transcribe',
    'transcription', 'whisper',
  ]),
  ChatTopic('record_voice_over', Icons.record_voice_over_rounded, [
    'talk', 'pitch', 'speaker notes', 'public speaking', 'narration',
  ]),
  ChatTopic('newspaper', Icons.newspaper_rounded, [
    'news', 'headlines', 'press',
  ]),
  ChatTopic('public', Icons.public_rounded, [
    'world', 'global', 'politics', 'election', 'country', 'geography',
  ]),

  // Home and life.
  ChatTopic('sensors', Icons.sensors_rounded, [
    'home assistant', 'sensor', 'sensors', 'zigbee', 'zwave', 'z-wave',
    'matter', 'smart home', 'homekit', 'motion',
  ]),
  ChatTopic('light', Icons.light_rounded, [
    'lights', 'lighting', 'lamp', 'bulb', 'hue', 'led',
  ]),
  ChatTopic('thermostat', Icons.thermostat_rounded, [
    'thermostat', 'heating', 'temperature', 'hvac', 'cooling', 'heat pump',
    'nest',
  ]),
  ChatTopic('bolt', Icons.bolt_rounded, [
    'power', 'energy', 'electricity', 'solar', 'ups', 'outlet', 'wattage',
  ]),
  ChatTopic('battery_charging_full', Icons.battery_charging_full_rounded, [
    'battery', 'charge', 'charging', 'charger',
  ]),
  ChatTopic('water_drop', Icons.water_drop_rounded, [
    'water', 'leak', 'leaking', 'plumbing', 'hose', 'sprinkler', 'rain',
    'humidity', 'pipe', 'pipes',
  ]),
  ChatTopic('yard', Icons.yard_rounded, [
    'garden', 'gardening', 'yard', 'lawn', 'plant', 'irrigation', 'seeds',
    'vegetables', 'compost',
  ]),
  ChatTopic('local_florist', Icons.local_florist_rounded, [
    'flowers', 'flower', 'bouquet', 'florist',
  ]),
  ChatTopic('eco', Icons.eco_rounded, [
    'environment', 'climate', 'sustainability', 'recycling', 'recycle',
    'carbon',
  ]),
  ChatTopic('park', Icons.park_rounded, [
    'tree', 'trees', 'park', 'hiking', 'hike', 'nature', 'outdoors',
    'camping', 'trail',
  ]),
  ChatTopic('wb_sunny', Icons.wb_sunny_rounded, [
    'weather', 'forecast', 'sun', 'sunny', 'heatwave', 'uv',
  ]),
  ChatTopic('ac_unit', Icons.ac_unit_rounded, [
    'snow', 'winter', 'cold', 'freezer', 'frost', 'ski', 'skiing',
  ]),
  ChatTopic('home', Icons.home_rounded, [
    'house', 'home', 'apartment', 'rent', 'moving', 'landlord', 'lease',
    'household', 'condo',
  ]),
  ChatTopic('real_estate_agent', Icons.real_estate_agent_rounded, [
    'real estate', 'property', 'realtor', 'house hunting', 'listing price',
  ]),
  ChatTopic('cleaning_services', Icons.cleaning_services_rounded, [
    'clean', 'cleaning', 'chores', 'laundry', 'vacuum', 'dishes',
  ]),
  ChatTopic('pets', Icons.pets_rounded, [
    'pet', 'dog', 'cat', 'vet', 'puppy', 'kitten', 'litter', 'dog food',
  ]),
  ChatTopic('family_restroom', Icons.family_restroom_rounded, [
    'family', 'kids', 'children', 'parents', 'parenting', 'mom', 'dad',
  ]),
  ChatTopic('child_care', Icons.child_care_rounded, [
    'baby', 'toddler', 'childcare', 'daycare', 'nanny',
  ]),
  ChatTopic('favorite', Icons.favorite_rounded, [
    'love', 'relationship', 'dating', 'wedding', 'anniversary', 'partner',
  ]),
  ChatTopic('card_giftcard', Icons.card_giftcard_rounded, [
    'gift', 'gifts', 'present', 'presents', 'christmas', 'wishlist',
  ]),
  ChatTopic('cake', Icons.cake_rounded, ['birthday', 'cake', 'birthdays']),
  ChatTopic('celebration', Icons.celebration_rounded, [
    'party', 'celebration', 'celebrate', 'new year', 'halloween',
  ]),
  ChatTopic('confirmation_number', Icons.confirmation_number_rounded, [
    'ticket', 'tickets', 'concert', 'concerts', 'festival', 'theatre',
    'theater',
  ]),
  ChatTopic('mood', Icons.mood_rounded, [
    'mood', 'feelings', 'emotion', 'emotions', 'happy', 'sad', 'anxious',
    'anxiety',
  ]),
  ChatTopic('self_improvement', Icons.self_improvement_rounded, [
    'meditation', 'mindfulness', 'wellbeing', 'well-being', 'stress',
    'habit', 'habits', 'therapy',
  ]),
  ChatTopic('bedtime', Icons.bedtime_rounded, [
    'sleep', 'sleeping', 'bedtime', 'insomnia', 'nap',
  ]),
  ChatTopic('medical_services', Icons.medical_services_rounded, [
    'health', 'doctor', 'medical', 'symptoms', 'symptom', 'pain',
    'hospital', 'injury', 'diagnosis', 'blood',
  ]),
  ChatTopic('medication', Icons.medication_rounded, [
    'medication', 'medicine', 'pill', 'pills', 'dose', 'prescription',
    'supplement', 'supplements', 'vitamin',
  ]),
  ChatTopic('fitness_center', Icons.fitness_center_rounded, [
    'fitness', 'workout', 'gym', 'exercise', 'training', 'strength',
    'weights', 'lifting',
  ]),
  ChatTopic('directions_run', Icons.directions_run_rounded, [
    'running', 'marathon', 'jog', 'jogging', '5k', '10k',
  ]),
  ChatTopic('directions_bike', Icons.directions_bike_rounded, [
    'bike', 'cycling', 'bicycle', 'ride', 'peloton',
  ]),
  ChatTopic('pool', Icons.pool_rounded, ['swim', 'swimming', 'pool', 'beach']),
  ChatTopic('sports_soccer', Icons.sports_soccer_rounded, [
    'soccer', 'football', 'nfl', 'sport', 'sports', 'match', 'league',
    'packers', 'score', 'playoffs',
  ]),
  ChatTopic('sports_esports', Icons.sports_esports_rounded, [
    'game', 'games', 'gaming', 'steam', 'xbox', 'playstation', 'nintendo',
    'switch game', 'minecraft',
  ]),
  ChatTopic('music_note', Icons.music_note_rounded, [
    'music', 'song', 'spotify', 'playlist', 'album', 'guitar', 'piano',
    'band', 'lyrics',
  ]),
  ChatTopic('headphones', Icons.headphones_rounded, [
    'podcast', 'podcasts', 'headphones', 'listen', 'listening',
  ]),
  ChatTopic('movie', Icons.movie_rounded, [
    'media', 'movie', 'film', 'show', 'shows', 'netflix', 'plex', 'jellyfin',
    'series', 'episode', 'anime',
  ]),
  ChatTopic('restaurant_menu', Icons.restaurant_menu_rounded, [
    'recipe', 'cooking', 'cook', 'bake', 'baking', 'kitchen', 'ingredients',
  ]),
  ChatTopic('restaurant', Icons.restaurant_rounded, [
    'food', 'restaurant', 'dinner', 'lunch', 'breakfast', 'eat', 'eating',
    'meal', 'diet', 'nutrition', 'calories',
  ]),
  ChatTopic('local_cafe', Icons.local_cafe_rounded, [
    'coffee', 'cafe', 'espresso', 'tea', 'latte',
  ]),
  ChatTopic('local_bar', Icons.local_bar_rounded, [
    'wine', 'beer', 'cocktail', 'cocktails', 'drinks', 'bar', 'whisky',
  ]),
  ChatTopic('checkroom', Icons.checkroom_rounded, [
    'clothes', 'clothing', 'outfit', 'fashion', 'wardrobe', 'shoes', 'jacket',
  ]),
  ChatTopic('content_cut', Icons.content_cut_rounded, [
    'haircut', 'hair', 'barber', 'salon',
  ]),
  ChatTopic('shopping_cart', Icons.shopping_cart_rounded, [
    'shopping', 'buy', 'buying', 'purchase', 'order', 'orders', 'amazon',
    'groceries', 'grocery', 'cart',
  ]),
  ChatTopic('local_shipping', Icons.local_shipping_rounded, [
    'shipping', 'delivery', 'package', 'tracking', 'parcel', 'ups', 'fedex',
    'usps', 'courier',
  ]),

  // Time.
  ChatTopic('schedule', Icons.schedule_rounded, [
    'schedule', 'cron', 'timer', 'reminder', 'reminders', 'recurring',
    'daily', 'nightly', 'weekly', 'hourly', 'deadline',
  ]),
  ChatTopic('alarm', Icons.alarm_rounded, ['alarm', 'alarms', 'wake up']),
  ChatTopic('calendar_month', Icons.calendar_month_rounded, [
    'calendar', 'event', 'events', 'meeting', 'meetings', 'appointment',
    'agenda', 'plans', 'weekend',
  ]),

  // Getting around.
  ChatTopic('flight', Icons.flight_rounded, [
    'flight', 'fly', 'airport', 'airline', 'trip', 'travel', 'vacation',
    'holiday', 'itinerary', 'lisbon', 'paris', 'tokyo', 'london',
  ]),
  ChatTopic('hotel', Icons.hotel_rounded, [
    'hotel', 'airbnb', 'stay', 'booking', 'lodging', 'hostel',
  ]),
  ChatTopic('luggage', Icons.luggage_rounded, [
    'packing', 'luggage', 'suitcase', 'carry-on',
  ]),
  ChatTopic('map', Icons.map_rounded, [
    'map', 'maps', 'route', 'directions', 'navigation', 'location',
    'address', 'gps',
  ]),
  ChatTopic('directions_car', Icons.directions_car_rounded, [
    'car', 'cars', 'drive', 'driving', 'vehicle', 'tesla', 'ev', 'mechanic',
    'tire', 'tyres', 'tires',
  ]),
  ChatTopic('local_gas_station', Icons.local_gas_station_rounded, [
    'gas', 'fuel', 'petrol', 'diesel',
  ]),
  ChatTopic('train', Icons.train_rounded, [
    'train', 'transit', 'subway', 'commute', 'metro', 'bus',
  ]),
  ChatTopic('sailing', Icons.sailing_rounded, [
    'boat', 'sailing', 'sea', 'ocean', 'kayak',
  ]),

  // Generic, last.
  ChatTopic('accessibility_new', Icons.accessibility_new_rounded, [
    'accessibility', 'a11y', 'talkback', 'screen reader', 'contrast',
  ]),
  ChatTopic('verified', Icons.verified_rounded, [
    'verified', 'verification', 'certificate', 'certificates', 'ssl', 'tls',
  ]),
  ChatTopic('block', Icons.block_rounded, ['block', 'blocked', 'ban', 'spam']),
  ChatTopic('emoji_events', Icons.emoji_events_rounded, [
    'award', 'awards', 'win', 'winner', 'contest', 'competition', 'trophy',
  ]),
  ChatTopic('volunteer_activism', Icons.volunteer_activism_rounded, [
    'charity', 'donate', 'donation', 'volunteer', 'volunteering',
  ]),
  ChatTopic('star', Icons.star_rounded, ['rating', 'ratings', 'favourite']),
  ChatTopic('tag', Icons.tag_rounded, ['hashtag', 'tags', 'label', 'labels']),
  ChatTopic('settings', Icons.settings_rounded, [
    'settings', 'config', 'configuration', 'setup', 'set up', 'configure',
    'preferences', 'options', 'enable', 'disable',
  ]),
  ChatTopic('tune', Icons.tune_rounded, ['tune', 'tuning', 'adjust']),
  ChatTopic('format_list_bulleted', Icons.format_list_bulleted_rounded, [
    'list', 'lists', 'ranking', 'top 10', 'enumerate',
  ]),
  ChatTopic('search', Icons.search_rounded, [
    'search', 'find', 'lookup', 'look up', 'locate', 'where is',
  ]),
  ChatTopic('info', Icons.info_rounded, [
    'identify', 'info', 'information', 'about', 'what is', 'who is',
    'current',
  ]),
  ChatTopic('help', Icons.help_rounded, [
    'help', 'question', 'how do', 'how to', 'why', 'explain', 'confused',
  ]),
];
// dart format on

final Map<String, ChatTopic> _topicsByName = {
  for (final topic in chatTopics) topic.name: topic,
};

/// The topic named [name], or null when it is not in the vocabulary — the
/// check every answer from Hermes goes through.
ChatTopic? chatTopicNamed(String? name) =>
    name == null ? null : _topicsByName[name.trim().toLowerCase()];

/// Picks the topic that best fits [title] on the device: a whole-phrase
/// match scores 3, a whole word 2, and a longer word it starts 1. Ties go to
/// the earlier topic. Returns null when nothing matches.
ChatTopic? matchChatTopic(String title) {
  final words = title
      .toLowerCase()
      .replaceAll('’', '\'')
      .split(RegExp(r"[^a-z0-9'+-]+"))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return null;
  final padded = ' ${words.join(' ')} ';
  ChatTopic? best;
  var bestScore = 0;
  for (final topic in chatTopics) {
    var score = 0;
    for (final keyword in topic.keywords) {
      if (keyword.contains(' ') && padded.contains(' $keyword ')) score += 3;
    }
    // Each distinct word of the title counts once per topic, at its best
    // fit: "automations" does not score for both "automation" and
    // "automations", nor "Claude … Claude" twice.
    for (final word in words.toSet()) {
      var best = 0;
      for (final keyword in topic.keywords) {
        if (keyword.contains(' ')) continue;
        if (word == keyword ||
            word == '${keyword}s' ||
            word == '${keyword}es') {
          best = 2;
          break;
        }
        if (keyword.length >= 5 && word.startsWith(keyword)) best = 1;
      }
      score += best;
    }
    if (score > bestScore) {
      best = topic;
      bestScore = score;
    }
  }
  return best;
}
