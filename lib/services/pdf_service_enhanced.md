# PDF Service Enhancement Notes

The PDF service has been enhanced to include meal calculations. However, due to the synchronous nature of the PDF build callback, meal statistics need to be pre-calculated before PDF generation.

## Implementation Approach

The meal calculations are added to the PDF when:
1. Meals data is passed to `generateExpenseReport`
2. Group type is `bachelorMess`
3. Meal statistics are pre-calculated before PDF build

## Current Status

The PDF service signature has been updated to accept optional meals parameter. The meal calculation section will be added to the PDF after expense details.

## Next Steps

To complete the implementation, the meal statistics need to be pre-calculated at the call site (in group_details_screen.dart) before generating the PDF, and passed as pre-calculated data to avoid async operations in the synchronous PDF build context.

