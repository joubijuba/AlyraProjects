

const { BN, expectRevert, expectEvent } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const constants = require('@openzeppelin/test-helpers/src/constants');

const Voting = artifacts.require("./Voting.sol");

contract("Voting", ([owner, voterOne, voterTwo, voterThree, stranger]) => {

  let VotingInstance

  beforeEach(async function () {
    VotingInstance = await Voting.new({ from: owner })
  })

        /// getVoter TEST ///

  it("getVoter retrieves effectively a voter / non voter from mapping", async function (){
    
      // we need to whitelist some address in order to use the getVoter getter. We will then choose the voterOne address, and use getVoter on voterTwo
    await VotingInstance.addVoter(voterOne, {from : owner})
    const voterTwoObject = await VotingInstance.getVoter(voterTwo, {from : voterOne})

      // voterTwo isn't whitelisted, then voterTwoObject.isRegistred should return false
    expect(voterTwoObject.isRegistered).to.equal(false, "the user isn't registered")

      // let's also do it on voterOne. Let's check that indeed, voterOne.isRegistered returns true
    const voterOneObject = await VotingInstance.getVoter(voterOne, {from : voterOne})
    expect(voterOneObject.isRegistered).to.equal(true)

  })

      /// addVoter TEST ///

  it("the user has been whitelisted, the addVoter event has been emitted and the require is checked", async function () {

      // we could check if the initial voterOne.isRegistered == false, but we already checked this in the getVoter test

      // first we whitelist voterOne
    const whitelistOne = await VotingInstance.addVoter(voterOne, { from: owner })

      // we check require (isRegistered == false) testing
    await expectRevert(VotingInstance.addVoter(voterOne), "Already registered")
      // we check the event emission
    await expectEvent(whitelistOne, "VoterRegistered")


      // we finally check if voterOne.isRegistered == true
    const voterOneAfterWL = await (VotingInstance.getVoter(voterOne, {from : voterOne}))
    const voterOneStatusAfterWL = await (voterOneAfterWL.isRegistered)

    expect(voterOneStatusAfterWL).to.equal(true, "not working")

  })

        /// addProposal TEST ///

  it("the proposal has been added, the addProposal events have been emitted and the requires do work", async function () {

      // we enable voterOne ability to vote
    await VotingInstance.addVoter(voterOne, { from: owner })

      // we start the voting session
    await VotingInstance.startProposalsRegistering()

      // voterOne adds his proposal
    const voterOneProposal = await VotingInstance.addProposal("légaliser la weed", { from: voterOne })

      // we then check 2 requires : onlyVoter and also if the proposal is empty or no
    await expectRevert(VotingInstance.addProposal("aaaBBB", { from: voterTwo }), "You're not a voter")
    await expectRevert(VotingInstance.addProposal("", { from : voterOne}), "Vous ne pouvez pas ne rien proposer")

      // we check the event emission and its log
    await expectEvent(voterOneProposal, "ProposalRegistered", {proposalId : new BN (1)})
  })

        /// startProposals TEST /// 

    // here we will change that the event is correctly emitted and in consequence that the workflowstatus has changed
  it ("workflowstatus changed and event emitted", async function (){
    const WFstatusChange = await VotingInstance.startProposalsRegistering({from : owner})
    expectEvent(WFstatusChange, "WorkflowStatusChange", {
      previousStatus: new BN(Voting.WorkflowStatus.RegisteringVoters),
      newStatus: new BN(Voting.WorkflowStatus.ProposalsRegistrationStarted)
    });

      // let's also check if a user other than the owner can trigger this function
    await expectRevert(VotingInstance.startProposalsRegistering({from : voterOne}), "caller is not the owner")
  })

        /// setVote TEST ///

  it ("vote has been casted, event has been emitted and the different requires are checked", async function (){
      // first we will add voterOne, then the owner will start the Proposals registration session. VoterOne will add a proposal
      // and straight after, the owner will end the proposals registration. Then the owner will start the voting session. 
      // We will check the "proposal not found" require. 
      // Then the voterOne casts his vote for the proposalID = 1
      // Then we will check the double-voting require with voterOne attempting an other vote
      // Then we will check if the proposal attributes and the voter attributes have been affected correctly
    await VotingInstance.addVoter(voterOne, {from : owner})
    await VotingInstance.startProposalsRegistering({from : owner})
    await VotingInstance.addProposal("légaliser la weed", {from : voterOne})
    await VotingInstance.endProposalsRegistering({from : owner})
    await VotingInstance.startVotingSession({from : owner})
    await expectRevert(VotingInstance.setVote(new BN(2), {from : voterOne}), "Proposal not found")
    const vote = await VotingInstance.setVote(new BN(1),{from : voterOne})
    await expectRevert(VotingInstance.setVote(new BN(1), {from : voterOne}), "You have already voted")
    const proposal = await VotingInstance.getOneProposal(new BN(1), {from : voterOne})
    expect(proposal.voteCount).to.be.bignumber.equal(new BN(1), "vote hasnt been accounted correctly")
    const voterOneObject = await VotingInstance.getVoter(voterOne, {from : voterOne})
    expect(voterOneObject.hasVoted).to.equal(true, "hasVoted not affected")
    expect(voterOneObject.votedProposalId).to.be.bignumber.equal(new BN(1), "votedProposalId not affected")

      // Let's also check if the onlyVoter modifier is working correctly
      await expectRevert(VotingInstance.setVote(new BN(1), {from : voterTwo}), "You're not a voter")
  })

})

