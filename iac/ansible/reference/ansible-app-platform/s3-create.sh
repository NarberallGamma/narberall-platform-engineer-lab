for stand in dev dev2 dev3 test test2 test3 demo preprod; do
obsutil mb obs://platform-email-templates-$stand
obsutil mb obs://platform-email-templates-$stand
obsutil mb obs://platform-contract-additional-files-$stand
obsutil mb obs://platform-statement-bc-$stand
obsutil mb obs://platform-invoice-order-$stand
obsutil mb obs://platform-contracts-$stand
obsutil mb obs://platform-chat-$stand
done
