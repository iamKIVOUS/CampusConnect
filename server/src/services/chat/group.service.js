/**
 * @file Business logic for group-specific chat operations.
 * @author Your Name
 * @version 1.0.0
 */
import models from '../../models/index.js';
import { AppError } from '../../utils/error.js';
import { checkAdminPermissions, formatUserProfile, createAndBroadcastSystemMessage } from './chat.helpers.js';
import { getFullConversation } from './conversation.service.js';

const { Member, Auth, Student, Employee, Conversation, sequelize } = models;
import { Op } from 'sequelize';

/**
 * Adds one or more members to a group. Requires admin privileges.
 */
export const addMembersToGroup = async ({ conversationId, actorId, newMemberIds }) => {
  return sequelize.transaction(async (t) => {
    const actor = await checkAdminPermissions(conversationId, actorId, t);
    const actorName = formatUserProfile(actor.Auth)?.name || 'An admin';
    
    const existingMembers = await Member.findAll({ where: { conversationId, userId: { [Op.in]: newMemberIds } }, transaction: t, raw: true });
    const membersToAddIds = newMemberIds.filter(id => !existingMembers.some(em => em.userId === id));
    
    if (membersToAddIds.length === 0) throw new AppError('All users are already members.', 400);
    
    const newMemberProfiles = await Auth.findAll({ where: { enrollment_number: { [Op.in]: membersToAddIds } }, include: [Student, Employee], transaction: t });
    const memberObjects = membersToAddIds.map(userId => ({ conversationId, userId, role: 'member' }));
    await Member.bulkCreate(memberObjects, { transaction: t });
    
    const newMemberNames = newMemberProfiles.map(p => formatUserProfile(p)?.name).join(', ');
    await createAndBroadcastSystemMessage(conversationId, `${actorName} added ${newMemberNames} to the group.`, t);
    
    return getFullConversation(conversationId, actorId, t);
  });
};

/**
 * Removes a member from a group. Requires admin privileges.
 */
export const removeMemberFromGroup = async ({ conversationId, actorId, memberToRemoveId }) => {
  return sequelize.transaction(async (t) => {
    const actor = await checkAdminPermissions(conversationId, actorId, t);
    if (actorId === memberToRemoveId) throw new AppError('Admins cannot remove themselves. Use "Leave Group" instead.', 400);
    
    const memberToRemove = await checkMembership(conversationId, memberToRemoveId, t);
    const actorName = formatUserProfile(actor.Auth)?.name || 'An admin';
    const memberName = formatUserProfile(memberToRemove.Auth)?.name || 'A user';
    
    await Member.destroy({ where: { conversationId, userId: memberToRemoveId }, transaction: t });
    await createAndBroadcastSystemMessage(conversationId, `${actorName} removed ${memberName} from the group.`, t);
    
    return getFullConversation(conversationId, actorId, t);
  });
};

/**
 * Updates a member's role in a group (e.g., to 'admin'). Requires admin privileges.
 */
export const updateUserRoleInGroup = async ({ conversationId, actorId, targetUserId, newRole }) => {
  return sequelize.transaction(async (t) => {
    const actor = await checkAdminPermissions(conversationId, actorId, t);
    if (actorId === targetUserId) throw new AppError('Admins cannot change their own role.', 400);
    
    const targetUser = await checkMembership(conversationId, targetUserId, t);
    const actorName = formatUserProfile(actor.Auth)?.name || 'An admin';
    const memberName = formatUserProfile(targetUser.Auth)?.name || 'A user';
    
    await Member.update({ role: newRole }, { where: { conversationId, userId: targetUserId }, transaction: t });
    const actionText = newRole === 'admin' ? `promoted ${memberName} to admin` : `demoted ${memberName} to member`;
    await createAndBroadcastSystemMessage(conversationId, `${actorName} ${actionText}.`, t);
    
    return getFullConversation(conversationId, actorId, t);
  });
};

/**
 * Allows a user to leave a group. If the last admin leaves, another member is promoted.
 */
export const leaveGroup = async ({ conversationId, userId }) => {
  await sequelize.transaction(async (t) => {
    const member = await checkMembership(conversationId, userId, t);
    const memberName = formatUserProfile(member.Auth)?.name || 'A user';
    
    const admins = await Member.findAll({ where: { conversationId, role: 'admin' }, transaction: t });
    if (admins.length === 1 && admins[0].userId === userId) {
      const otherMembers = await Member.findAll({
        where: { conversationId, userId: { [Op.ne]: userId } },
        limit: 1,
        order: [['joined_at', 'ASC']],
        include: [{ model: Auth, include: [Student, Employee] }],
        transaction: t
      });
      if (otherMembers.length > 0) {
        const newAdmin = otherMembers[0];
        await Member.update({ role: 'admin' }, { where: { conversationId, userId: newAdmin.userId }, transaction: t });
        const newAdminName = formatUserProfile(newAdmin.Auth)?.name || 'A user';
        await createAndBroadcastSystemMessage(conversationId, `${memberName} left the group. ${newAdminName} is now an admin.`, t);
      }
    } else {
      await createAndBroadcastSystemMessage(conversationId, `${memberName} has left the group.`, t);
    }
    
    await Member.destroy({ where: { conversationId, userId }, transaction: t });
  });
  
  return { success: true, message: 'Successfully left the group.' };
};

/**
 * Updates a group's details (e.g., title, photo). Requires admin privileges.
 */
export const updateGroupDetails = async ({ conversationId, actorId, details }) => {
  return sequelize.transaction(async (t) => {
    const actor = await checkAdminPermissions(conversationId, actorId, t);
    const actorName = formatUserProfile(actor.Auth)?.name || 'An admin';
    
    const conversation = await Conversation.findByPk(conversationId, { transaction: t });
    if (!conversation) throw new AppError('Conversation not found', 404);
    
    const oldTitle = conversation.title;
    await conversation.update(details, { transaction: t });
    
    if (details.title && details.title !== oldTitle) {
      await createAndBroadcastSystemMessage(conversationId, `${actorName} changed the group name to "${details.title}".`, t);
    }
    
    return getFullConversation(conversationId, actorId, t);
  });
};
