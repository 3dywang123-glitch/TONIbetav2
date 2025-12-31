// Expert menu mapping
const EXPERTS_MENU = {
  0: { name: 'chat_only', desc: '无需专家，仅进行日常闲聊、问候、撒娇或情感互动' },
  1: { name: 'psychology', desc: '心理咨询、情感分析、聊天记录解读、情绪安抚' },
  2: { name: 'mckinsey', desc: '商业策略、职场生存、PPT优化、效率管理、赚钱逻辑' },
  3: { name: 'medical', desc: '医疗咨询、药物说明书解读、化验单分析 (非临床诊断)' },
  4: { name: 'legal', desc: '法律咨询、合同风险审查、侵权责任判定' },
  5: { name: 'tutor', desc: '作业辅导、题目讲解、作文批改、知识点解析 (各学科)' },
  6: { name: 'general_engineer', desc: '硬件维修、机械故障、家电修理、物理电路' },
  7: { name: 'code_engineer', desc: '代码Debug、编程指导、软件架构、算法优化' },
  8: { name: 'data_analyst', desc: '数据分析、Excel报表解读、趋势预测、图表洞察' },
  9: { name: 'fashion', desc: '时尚设计、穿搭打分、剪裁面料分析、潮流趋势' },
  10: { name: 'shopper', desc: '购物决策、性价比分析、真伪鉴别、产品对比、避坑指南' },
  11: { name: 'finance', desc: '个人理财、税务规划、投资建议、省钱规划' },
  12: { name: 'chef', desc: '食材识别、烹饪菜谱、营养搭配、美食点评' },
  13: { name: 'pet_expert', desc: '宠物行为分析、猫狗疾病初筛、饲养建议' },
  14: { name: 'parenting', desc: '育儿建议、家庭教育、青少年心理、亲子关系 (非解题)' },
  15: { name: 'fengshui', desc: '家居风水布局、环境气场分析、开运建议' },
  16: { name: 'translator', desc: '多语言精准翻译、跨文化交流、外语学习' },
  17: { name: 'detective', desc: '微观细节观察、照片定位、逻辑推理、寻物' },
  18: { name: 'travel', desc: '旅游攻略、景点识别、行程规划、交通建议' },
  19: { name: 'writer', desc: '文案润色、公文写作、创意写作、剧本大纲' },
  20: { name: 'fitness', desc: '健身动作指导、训练计划、肌肉解剖、运动康复' },
};

function getExpertMenuText() {
  const lines = ['【请分析用户意图，从下方列表中选择最合适的一个 ID】'];
  for (const [number, info] of Object.entries(EXPERTS_MENU)) {
    lines.push(`${number}. ${info.name} (${info.desc})`);
  }
  return lines.join('\n');
}

function getExpertNameById(id) {
  const expert = EXPERTS_MENU[id];
  return expert ? expert.name : 'general_engineer';
}

function getExpertIdByName(name) {
  for (const [id, expert] of Object.entries(EXPERTS_MENU)) {
    if (expert.name === name) {
      return parseInt(id);
    }
  }
  return 6; // Default to general_engineer
}

module.exports = {
  EXPERTS_MENU,
  getExpertMenuText,
  getExpertNameById,
  getExpertIdByName,
};

